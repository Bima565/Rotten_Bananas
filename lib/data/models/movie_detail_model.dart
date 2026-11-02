import 'genre_model.dart';

class VideoModel {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;

  const VideoModel({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    required this.official,
  });

  bool get isYouTube => site.toLowerCase() == 'youtube';
  bool get isTrailer => type.toLowerCase() == 'trailer';

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? 'Trailer',
      site: json['site'] as String? ?? '',
      type: json['type'] as String? ?? '',
      official: json['official'] as bool? ?? false,
    );
  }
}

class CastModel {
  final int id;
  final String name;
  final String character;
  final String? profilePath;

  const CastModel({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  String get profileUrl => profilePath != null && profilePath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : '';

  factory CastModel.fromJson(Map<String, dynamic> json) {
    return CastModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Aktor',
      character: json['character'] as String? ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }
}

class MovieDetailModel {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String releaseDate;
  final int runtime; // dalam menit
  final String status;
  final String tagline;
  final List<GenreModel> genres;
  final List<VideoModel> videos;
  final List<CastModel> cast;

  const MovieDetailModel({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.releaseDate,
    required this.runtime,
    required this.status,
    required this.tagline,
    required this.genres,
    required this.videos,
    required this.cast,
  });

  String get posterUrl => posterPath != null && posterPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : '';

  String get backdropUrl => backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : '';

  String get releaseYear {
    if (releaseDate.isEmpty) return '';
    return releaseDate.split('-').first;
  }

  String get formattedDuration {
    if (runtime <= 0) return 'N/A';
    final hours = runtime ~/ 60;
    final minutes = runtime % 60;
    if (hours > 0) {
      return '${hours}j ${minutes}m';
    }
    return '${minutes}m';
  }

  VideoModel? get mainTrailer {
    final youTubeVideos = videos.where((v) => v.isYouTube).toList();
    if (youTubeVideos.isEmpty) return null;

    // Utamakan video type 'Trailer' yang official
    final officialTrailer = youTubeVideos.firstWhere(
      (v) => v.isTrailer && v.official,
      orElse: () => youTubeVideos.firstWhere(
        (v) => v.isTrailer,
        orElse: () => youTubeVideos.first,
      ),
    );
    return officialTrailer;
  }

  factory MovieDetailModel.fromJson(Map<String, dynamic> json) {
    final genreList = (json['genres'] as List<dynamic>?)
            ?.map((g) => GenreModel.fromJson(g as Map<String, dynamic>))
            .toList() ??
        [];

    final videoResults = (json['videos']?['results'] as List<dynamic>?)
            ?.map((v) => VideoModel.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [];

    final castResults = (json['credits']?['cast'] as List<dynamic>?)
            ?.map((c) => CastModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return MovieDetailModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Tanpa Judul',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      releaseDate: json['release_date'] as String? ?? '',
      runtime: json['runtime'] as int? ?? 0,
      status: json['status'] as String? ?? 'Released',
      tagline: json['tagline'] as String? ?? '',
      genres: genreList,
      videos: videoResults,
      cast: castResults,
    );
  }
}
