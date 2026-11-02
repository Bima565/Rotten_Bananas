import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/app_colors.dart';
import 'package:flutter_application_1/core/banana_score_helper.dart';
import 'package:flutter_application_1/core/password_hasher.dart';
import 'package:flutter_application_1/data/models/genre_model.dart';
import 'package:flutter_application_1/data/models/movie_model.dart';
import 'package:flutter_application_1/data/models/user_model.dart';

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
}
