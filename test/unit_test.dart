import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/app_colors.dart';
import 'package:flutter_application_1/core/banana_score_helper.dart';
import 'package:flutter_application_1/core/debouncer.dart';
import 'package:flutter_application_1/core/password_hasher.dart';
import 'package:flutter_application_1/data/models/genre_model.dart';
import 'package:flutter_application_1/data/models/movie_detail_model.dart';
import 'package:flutter_application_1/data/models/movie_model.dart';
import 'package:flutter_application_1/data/models/user_model.dart';
import 'package:flutter_application_1/data/services/tmdb_service.dart';
import 'package:flutter_application_1/page/category_movies_page.dart';

void main() {
  group('BananaScoreHelper Tests', () {
    test('vote_average >= 7.5 returns Golden Ripe', () {
      final score = BananaScoreHelper.calculate(8.5);
      expect(score.percentage, 85);
      expect(score.label, 'Golden Ripe');
      expect(score.icon, '🍌');
      expect(score.color, AppColors.statusFresh);
    });

    test('vote_average between 5.5 and 7.4 returns Bruised', () {
      final score = BananaScoreHelper.calculate(6.8);
      expect(score.percentage, 68);
      expect(score.label, 'Bruised');
      expect(score.icon, '🍌');
      expect(score.color, AppColors.statusBruised);
    });

    test('vote_average < 5.5 returns Rotten Bananas', () {
      final score = BananaScoreHelper.calculate(4.2);
      expect(score.percentage, 42);
      expect(score.label, 'Rotten Bananas');
      expect(score.icon, '🤢');
      expect(score.color, AppColors.statusRotten);
    });
  });

  group('CategoryType Tests', () {
    test('CategoryType contains all 5 required modes', () {
      expect(CategoryType.values.length, 5);
      expect(CategoryType.values.contains(CategoryType.nowPlaying), isTrue);
      expect(CategoryType.values.contains(CategoryType.popular), isTrue);
      expect(CategoryType.values.contains(CategoryType.topRated), isTrue);
      expect(CategoryType.values.contains(CategoryType.upcoming), isTrue);
      expect(CategoryType.values.contains(CategoryType.genre), isTrue);
    });
  });

  group('PasswordHasher Tests', () {
    test('SHA-256 hash is deterministic and verifies correctly', () {
      const password = 'password123';
      final hash1 = PasswordHasher.hash(password);
      final hash2 = PasswordHasher.hash(password);
      expect(hash1, hash2);
      expect(PasswordHasher.verify(password, hash1), isTrue);
      expect(PasswordHasher.verify('wrongpassword', hash1), isFalse);
    });
  });

  group('UserModel Tests', () {
    test('toMap and fromMap serialize correctly', () {
      final user = UserModel(
        id: 1,
        fullName: 'Bima Prawira',
        username: 'bima_test',
        email: 'bima@example.com',
        passwordHash: 'dummyhash',
        bio: 'Tester bio',
        favoriteGenres: '28,12',
        createdAt: '2026-11-01T00:00:00Z',
        updatedAt: '2026-11-01T00:00:00Z',
      );

      final map = user.toMap();
      expect(map['full_name'], 'Bima Prawira');
      expect(map['username'], 'bima_test');

      final fromMapUser = UserModel.fromMap(map);
      expect(fromMapUser.id, 1);
      expect(fromMapUser.email, 'bima@example.com');
      expect(fromMapUser.favoriteGenres, '28,12');
    });
  });

  group('MovieModel Tests', () {
    test('fromJson parses TMDb JSON format correctly', () {
      final json = {
        'id': 101,
        'title': 'Dune: Messiah',
        'overview': 'Epic continuation of the Dune saga.',
        'poster_path': '/path_to_poster.jpg',
        'backdrop_path': '/path_to_backdrop.jpg',
        'vote_average': 8.8,
        'vote_count': 1200,
        'release_date': '2026-10-20',
        'genre_ids': [28, 878],
      };

      final movie = MovieModel.fromJson(json);
      expect(movie.id, 101);
      expect(movie.title, 'Dune: Messiah');
      expect(movie.releaseYear, '2026');
      expect(movie.posterUrl, 'https://image.tmdb.org/t/p/w500/path_to_poster.jpg');
      expect(movie.backdropUrl, 'https://image.tmdb.org/t/p/w780/path_to_backdrop.jpg');
      expect(movie.genreIds, [28, 878]);
    });
  });

  group('GenreModel Tests', () {
    test('defaultGenres contains essential genres', () {
      expect(GenreModel.defaultGenres.any((g) => g.id == 28 && g.name == 'Action'), isTrue);
      expect(GenreModel.defaultGenres.any((g) => g.id == 878 && g.name == 'Sci-Fi'), isTrue);
    });
  });

  group('MovieDetailModel and VideoModel Tests', () {
    test('VideoModel properties identify YouTube trailers', () {
      final trailer = VideoModel.fromJson({
        'id': 'v1',
        'key': 'dQw4w9WgXcQ',
        'name': 'Official Trailer',
        'site': 'YouTube',
        'type': 'Trailer',
        'official': true,
      });

      expect(trailer.isYouTube, isTrue);
      expect(trailer.isTrailer, isTrue);
      expect(trailer.official, isTrue);
    });

    test('MovieDetailModel formats duration and finds main trailer', () {
      final detail = MovieDetailModel(
        id: 1,
        title: 'Dune: Part Two',
        overview: 'Overview text',
        voteAverage: 8.5,
        voteCount: 4000,
        releaseDate: '2024-03-01',
        runtime: 166, // 2j 46m
        status: 'Released',
        tagline: 'Long live the fighters.',
        genres: [const GenreModel(id: 878, name: 'Sci-Fi')],
        videos: [
          const VideoModel(
            id: '1',
            key: 'Way9Dexny3w',
            name: 'Official Trailer 3',
            site: 'YouTube',
            type: 'Trailer',
            official: true,
          ),
        ],
        cast: [
          const CastModel(
            id: 1,
            name: 'Timothée Chalamet',
            character: 'Paul Atreides',
            profilePath: '/actor.jpg',
          ),
        ],
      );

      expect(detail.formattedDuration, '2j 46m');
      expect(detail.mainTrailer?.key, 'Way9Dexny3w');
      expect(detail.cast.first.name, 'Timothée Chalamet');
    });
  });

  group('Debouncer Tests', () {
    test('Debouncer runs action after specified delay', () async {
      final debouncer = Debouncer(milliseconds: 50);
      int callCount = 0;

      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);
      debouncer.run(() => callCount++);

      expect(callCount, 0); // Not called immediately
      await Future.delayed(const Duration(milliseconds: 80));
      expect(callCount, 1); // Debounced to 1 call
      debouncer.dispose();
    });
  });

  group('TmdbService Env Auth Tests', () {
    test('does not crash or send request when dotenv is not initialized', () async {
      final adapter = _FakeHttpClientAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = TmdbService(dio: dio);

      final movies = await service.getTrendingMovies();
      final genres = await service.getGenres();

      expect(movies, isEmpty);
      expect(genres, GenreModel.defaultGenres);
      expect(adapter.fetchCount, 0);
    });

    test('does not send request when tmdb_auth is missing in env', () async {
      dotenv.testLoad(fileInput: '');
      final adapter = _FakeHttpClientAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = TmdbService(dio: dio);

      final movies = await service.getTrendingMovies();

      expect(movies, isEmpty);
      expect(adapter.fetchCount, 0);
    });

    test('uses Bearer token from dotenv tmdb_auth without hardcoded fallback', () async {
      dotenv.testLoad(fileInput: 'tmdb_auth=test_env_token');
      final adapter = _FakeHttpClientAdapter(
        responseBody: jsonEncode({
          'results': [
            {
              'id': 42,
              'title': 'Env Movie',
              'overview': 'Loaded using env token.',
              'vote_average': 7.8,
              'vote_count': 100,
              'release_date': '2026-01-01',
              'genre_ids': [28],
            }
          ]
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = TmdbService(dio: dio);

      final movies = await service.getTrendingMovies();

      expect(adapter.fetchCount, 1);
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer test_env_token');
      expect(movies.length, 1);
      expect(movies.first.title, 'Env Movie');
    });
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  final String responseBody;
  int fetchCount = 0;
  RequestOptions? lastOptions;

  _FakeHttpClientAdapter({this.responseBody = '{"results": []}'});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    lastOptions = options;
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
