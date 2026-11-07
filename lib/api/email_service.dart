import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SendOtpResult {
  final bool success;
  final String message;

  SendOtpResult({required this.success, required this.message});
}

class EmailService {
  static final Dio _dio = Dio();

  static Future<SendOtpResult> sendOtpCode({
    required String targetEmail,
    required String otpCode,
  }) async {
    final apiKey = dotenv.env['BREVO_API_KEY'] ?? '';
    final senderEmail = dotenv.env['BREVO_SENDER_EMAIL'] ?? '';

    if (apiKey.isEmpty) {
      return SendOtpResult(
        success: false,
        message: 'Brevo API Key belum disetel di .env',
      );
    }

    try {
      final response = await _dio.post(
        'https://api.brevo.com/v3/smtp/email',
        options: Options(
          headers: {
            'api-key': apiKey,
            'Content-Type': 'application/json',
            'accept': 'application/json',
          },
        ),
        data: {
          'sender': {
            'name': 'Rotten Bananas',
            'email': senderEmail,
          },
          'to': [
            {'email': targetEmail}
          ],
          'subject': 'Kode Verifikasi Reset Password - Rotten Bananas',
          'htmlContent': '''
            <div style="font-family: Arial, sans-serif; padding: 24px; background: #0D0E12; color: #FFFFFF; border-radius: 12px; max-width: 480px; border: 1px solid #222633;">
              <h2 style="color: #FFC700; margin-top: 0;">ROTTEN BANANAS</h2>
              <p style="color: #E5E7EB; font-size: 14px;">Halo,</p>
              <p style="color: #9CA3AF; font-size: 14px;">Kami menerima permintaan pengaturan ulang kata sandi untuk akun Rotten Bananas Anda. Masukkan kode 5-digit berikut ke aplikasi:</p>
              <div style="background: #181A22; border: 1px solid #FFC700; border-radius: 8px; padding: 18px; text-align: center; margin: 20px 0;">
                <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #FFC700;">$otpCode</span>
              </div>
              <p style="color: #6B7280; font-size: 12px; margin-bottom: 0;">Kode ini berlaku selama 15 menit. Jika bukan Anda yang meminta, abaikan email ini.</p>
            </div>
          ''',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SendOtpResult(
          success: true,
          message: 'Kode berhasil dikirim ke $targetEmail',
        );
      } else {
        return SendOtpResult(
          success: false,
          message: 'Brevo (${response.statusCode}): ${response.data}',
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Koneksi error';
      return SendOtpResult(
        success: false,
        message: 'Brevo Error: $msg',
      );
    } catch (e) {
      return SendOtpResult(
        success: false,
        message: 'Koneksi error: $e',
      );
    }
  }
}
