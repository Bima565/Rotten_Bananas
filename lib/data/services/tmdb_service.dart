import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/genre_model.dart';
import '../models/movie_detail_model.dart';
import '../models/movie_model.dart';

class TmdbService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.themoviedb.org/3';

  TmdbService() {
    final token = dotenv.env['tmdb_auth'] ??
        'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4YTI3ZTg3NTEzMWZmYWE1ODY0MjMwNzliNTI1YWQyNyIsIm5iZiI6MTc5MjY0MzEyNC44MzgsInN1YiI6IjZhZDk5MDM0ZjkwYzY4NGJjNzE0MjYyMSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.8hZV3SRDOV8dBEl7VXCehNJEVrhCueanANHMm8SnUQk';

    _dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  Future<List<MovieModel>> getTrendingMovies() async {
    try {
      final response = await _dio.get(
        '/trending/movie/week',
        queryParameters: {'language': 'id-ID'},
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> getNowPlayingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/now_playing',
        queryParameters: {
          'language': 'id-ID',
          'region': 'ID',
          'page': page,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> getPopularMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/popular',
        queryParameters: {
          'language': 'id-ID',
          'page': page,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> getTopRatedMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/top_rated',
        queryParameters: {
          'language': 'id-ID',
          'page': page,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> getUpcomingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/upcoming',
        queryParameters: {
          'language': 'id-ID',
          'region': 'ID',
          'page': page,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> getMoviesByGenre({required int genreId, int page = 1}) async {
    try {
      final response = await _dio.get(
        '/discover/movie',
        queryParameters: {
          'language': 'id-ID',
          'with_genres': genreId,
          'sort_by': 'popularity.desc',
          'page': page,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MovieModel>> searchMovies(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await _dio.get(
        '/search/movie',
        queryParameters: {
          'language': 'id-ID',
          'query': cleanQuery,
          'page': page,
          'include_adult': false,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((m) => MovieModel.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<MovieDetailModel?> getMovieDetail(int movieId) async {
    try {
      final response = await _dio.get(
        '/movie/$movieId',
        queryParameters: {
          'language': 'id-ID',
          'append_to_response': 'videos,credits',
        },
      );
      return MovieDetailModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      // Fallback tanpa language jika id-ID tidak lengkap
      try {
        final fallbackResponse = await _dio.get(
          '/movie/$movieId',
          queryParameters: {
            'append_to_response': 'videos,credits',
          },
        );
        return MovieDetailModel.fromJson(fallbackResponse.data as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<GenreModel>> getGenres() async {
    try {
      final response = await _dio.get(
        '/genre/movie/list',
        queryParameters: {'language': 'id-ID'},
      );
      final genres = response.data['genres'] as List<dynamic>? ?? [];
      if (genres.isEmpty) return GenreModel.defaultGenres;
      return genres.map((g) => GenreModel.fromJson(g as Map<String, dynamic>)).toList();
    } catch (_) {
      return GenreModel.defaultGenres;
    }
  }
}
