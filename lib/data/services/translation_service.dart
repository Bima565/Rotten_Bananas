import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationStatus {
  cached,
  success,
  rateLimited,
  error,
}

class TranslationResult {
  final String text;
  final TranslationStatus status;
  final String? errorMessage;

  const TranslationResult({
    required this.text,
    required this.status,
    this.errorMessage,
  });

  bool get isTranslated =>
      status == TranslationStatus.success || status == TranslationStatus.cached;

  bool get isRateLimited => status == TranslationStatus.rateLimited;
}

class TranslationService {
  final Dio _dio;

  /// Cooldown batas waktu jika terkena 429 / Rate Limit
  static DateTime? _rateLimitCooldownUntil;

  /// Cache daftar model yang aktif dari Google AI Studio
  static List<String>? _cachedAvailableModels;

  TranslationService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }

  /// Cek apakah saat ini sedang dalam status limit / cooldown
  bool get isRateLimited {
    if (_rateLimitCooldownUntil == null) return false;
    if (DateTime.now().isAfter(_rateLimitCooldownUntil!)) {
      _rateLimitCooldownUntil = null; // Limit sudah kerestart
      return false;
    }
    return true;
  }

  /// Sisa detik cooldown jika sedang terkena limit
  int get remainingCooldownSeconds {
    if (_rateLimitCooldownUntil == null) return 0;
    final diff = _rateLimitCooldownUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Reset cooldown secara manual (misal saat user tap tombol coba lagi)
  void resetCooldown() {
    _rateLimitCooldownUntil = null;
  }

  /// Mengambil daftar model teks standar langsung dari Google Gemini API
  Future<List<String>> _resolveModels(String apiKey) async {
    if (_cachedAvailableModels != null && _cachedAvailableModels!.isNotEmpty) {
      return _cachedAvailableModels!;
    }

    final fallbackList = [
      'gemini-2.5-pro',
      'gemini-pro-latest',
      'gemini-2.5-flash',
    ];

    try {
      final response = await _dio.get(
        'https://generativelanguage.googleapis.com/v1beta/models',
        options: Options(
          headers: {'x-goog-api-key': apiKey},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final models = response.data['models'] as List<dynamic>? ?? [];
        final available = models
            .where((m) {
              final methods = (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
              return methods.contains('generateContent');
            })
            .map((m) => (m['name'] as String? ?? '').replaceFirst('models/', '').trim())
            .where((name) => name.isNotEmpty)
            // Saring keluar model multimodal khusus yang tidak punya kuota free tier (limit: 0)
            .where((name) {
              final lower = name.toLowerCase();
              return !lower.contains('omni') &&
                     !lower.contains('image') &&
                     !lower.contains('tts') &&
                     !lower.contains('transcribe') &&
                     !lower.contains('computer-use') &&
                     !lower.contains('customtools') &&
                     !lower.contains('banana') &&
                     !lower.contains('nano');
            })
            .toList();

        debugPrint('📋 [Gemini Text Models] Model teks yang disaring: $available');

        if (available.isNotEmpty) {
          // Prioritaskan model teks standar dengan kuota free tier stabil
          available.sort((a, b) {
            int score(String name) {
              final lower = name.toLowerCase();
              if (lower == 'gemini-2.5-pro') return 100;
              if (lower == 'gemini-pro-latest') return 95;
              if (lower.contains('2.5-pro')) return 90;
              if (lower.contains('pro-latest')) return 85;
              if (lower.contains('2.5-flash')) return 80;
              if (lower.contains('flash')) return 70;
              if (lower.contains('pro')) return 60;
              return 10;
            }
            return score(b).compareTo(score(a));
          });
          _cachedAvailableModels = available;
          return available;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Gemini ListModels Error] Menggunakan fallback list: $e');
    }

    return fallbackList;
  }

  /// Terjemahkan sinopsis film bahasa Inggris ke bahasa Indonesia menggunakan Google Gemini
  Future<TranslationResult> translateMovieOverview({
    required int movieId,
    required String englishText,
  }) async {
    final cleanEnglish = englishText.trim();
    if (cleanEnglish.isEmpty) {
      return const TranslationResult(
        text: '',
        status: TranslationStatus.cached,
      );
    }

    // 1. Cek Cache Lokal SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'gemini_trans_$movieId';
    final cached = prefs.getString(cacheKey);

    if (cached != null && cached.trim().isNotEmpty) {
      debugPrint('📦 [Gemini Cache] Menggunakan sinopsis tersimpan untuk movieId $movieId');
      return TranslationResult(
        text: cached.trim(),
        status: TranslationStatus.cached,
      );
    }

    // 2. Cek apakah Gemini sedang terkena Limit Cooldown
    if (isRateLimited) {
      debugPrint('⏳ [Gemini Cooldown] Sedang masa tunggu limit: $remainingCooldownSeconds detik lagi.');
      return TranslationResult(
        text: cleanEnglish, // Langsung kembalikan teks Inggris tanpa membuang request
        status: TranslationStatus.rateLimited,
        errorMessage: 'Gemini API limit sedang aktif. Sisa waktu: $remainingCooldownSeconds detik.',
      );
    }

    // 3. Ambil API Key dari .env
    final apiKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    if (apiKey.isEmpty) {
      debugPrint('⚠️ [Gemini Warning] GEMINI_API_KEY belum disetel atau .env belum dimuat (Perlu Hot Restart).');
      return TranslationResult(
        text: cleanEnglish,
        status: TranslationStatus.error,
        errorMessage: 'GEMINI_API_KEY belum disetel di .env (Coba Hot Restart aplikasi)',
      );
    }

    debugPrint('🔍 [Gemini API] Mengirim sinopsis movieId $movieId ke Gemini...');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Terjemahkan sinopsis film berikut ke dalam Bahasa Indonesia dengan gaya bahasa sinematik bioskop, mengalir, alami, dan menarik. Berikan HANYA teks hasil terjemahannya saja tanpa tanda kutip pembuka/penutup, tanpa teks pengantar, dan tanpa catatan tambahan:\n\n$cleanEnglish',
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 1024,
      },
    };

    // 4. Dapatkan model teks aktif dari Google AI Studio
    final modelsToTry = await _resolveModels(apiKey);
    debugPrint('🤖 [Gemini Models] Model urutan teratas: $modelsToTry');

    for (final model in modelsToTry) {
      try {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

        final response = await _dio.post(
          url,
          options: Options(
            headers: {
              'x-goog-api-key': apiKey,
            },
          ),
          data: requestBody,
        );

        if (response.statusCode == 200 && response.data != null) {
          final candidates = response.data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final translatedText = (parts[0]['text'] as String? ?? '').trim();
              if (translatedText.isNotEmpty) {
                // Simpan ke cache lokal HANYA jika terjemahan SUKSES
                await prefs.setString(cacheKey, translatedText);
                _rateLimitCooldownUntil = null;
                debugPrint('✅ [Gemini Sukses] Berhasil menerjemahkan sinopsis movieId $movieId dengan model $model');
                return TranslationResult(
                  text: translatedText,
                  status: TranslationStatus.success,
                );
              }
            }
          }
        }
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data?.toString() ?? '';
        final bodyText = responseData.toLowerCase();

        debugPrint('❌ [Gemini Error] Model: $model | Type: ${e.type} | Message: ${e.message} | HTTP $statusCode: $responseData');

        // Jika Google memberi pesan 'limit: 0', artinya model spesifik ini tidak punya free quota
        final isZeroQuotaModel = bodyText.contains('limit: 0');
        if (isZeroQuotaModel) {
          debugPrint('⚠️ [Gemini Skip] Model $model kuota free tier bernilai 0. Mencoba model lain...');
          continue;
        }

        final isRateLimit = statusCode == 429 ||
            bodyText.contains('resource_exhausted') ||
            bodyText.contains('quota') ||
            bodyText.contains('rate_limit');

        if (isRateLimit) {
          // Aktifkan cooldown selama 60 detik (1 menit) jika benar-benar terkena limit RPM
          _rateLimitCooldownUntil = DateTime.now().add(const Duration(seconds: 60));
          return TranslationResult(
            text: cleanEnglish, // Langsung tampilkan teks Inggris
            status: TranslationStatus.rateLimited,
            errorMessage: 'Gemini kuota tercapai (HTTP 429). Cooldown aktif 60 detik.',
          );
        }

        // Coba model berikutnya jika model saat ini gagal
        if (model != modelsToTry.last) {
          debugPrint('🔄 [Gemini Retry] Model $model gagal, mencoba model berikutnya...');
          continue;
        }

        return TranslationResult(
          text: cleanEnglish,
          status: TranslationStatus.error,
          errorMessage: 'Error Gemini HTTP $statusCode: $responseData',
        );
      } catch (e) {
        debugPrint('❌ [Gemini General Error] $e');
        if (model != modelsToTry.last) {
          continue;
        }
        return TranslationResult(
          text: cleanEnglish,
          status: TranslationStatus.error,
          errorMessage: e.toString(),
        );
      }
    }

    return TranslationResult(
      text: cleanEnglish,
      status: TranslationStatus.error,
      errorMessage: 'Gagal menerjemahkan dengan seluruh model Gemini',
    );
  }
}
