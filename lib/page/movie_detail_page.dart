import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../core/app_colors.dart';
import '../core/banana_score_helper.dart';
import '../data/models/movie_detail_model.dart';
import '../data/models/movie_model.dart';
import '../data/services/tmdb_service.dart';
import '../data/services/watchlist_service.dart';
import 'explore_filter_page.dart';

class MovieDetailPage extends StatefulWidget {
  final MovieModel movie;

  const MovieDetailPage({
    super.key,
    required this.movie,
  });

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final TmdbService _tmdbService = TmdbService();
  final WatchlistService _watchlistService = WatchlistService();

  MovieDetailModel? _detail;
  bool _isLoading = true;
  bool _isInWatchlist = false;

  YoutubePlayerController? _youtubeController;
  bool _isPlayingTrailer = false;
  String? _activeVideoKey;

  @override
  void initState() {
    super.initState();
    _loadDetailAndWatchlistStatus();
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  Future<void> _loadDetailAndWatchlistStatus() async {
    setState(() => _isLoading = true);

    final isSaved = await _watchlistService.isMovieInWatchlist(widget.movie.id);
    final detail = await _tmdbService.getMovieDetail(widget.movie.id);

    if (!mounted) return;

    setState(() {
      _isInWatchlist = isSaved;
      _detail = detail;
      _isLoading = false;

      final mainTrailer = detail?.mainTrailer;
      if (mainTrailer != null) {
        _activeVideoKey = mainTrailer.key;
        _initYoutubeController(mainTrailer.key);
      }
    });
  }

  void _initYoutubeController(String videoKey) {
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoKey,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
      ),
    );
  }

  void _playVideo(String videoKey) {
    setState(() {
      _activeVideoKey = videoKey;
      _isPlayingTrailer = true;
    });

    if (_youtubeController == null) {
      _initYoutubeController(videoKey);
    } else {
      _youtubeController!.loadVideoById(videoId: videoKey);
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final isNowSaved = await _watchlistService.toggleWatchlist(widget.movie);
      if (!mounted) return;

      setState(() {
        _isInWatchlist = isNowSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isNowSaved ? AppColors.statusFresh : AppColors.surfaceCard,
          content: Text(
            isNowSaved
                ? 'Film "${widget.movie.title}" disimpan ke Watchlist! 🔖'
                : 'Film dihapus dari Watchlist.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusRotten,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = BananaScoreHelper.calculate(_detail?.voteAverage ?? widget.movie.voteAverage);
    final backdropUrl = _detail?.backdropUrl.isNotEmpty == true
        ? _detail!.backdropUrl
        : widget.movie.backdropUrl;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentYellow),
            )
          : CustomScrollView(
        slivers: [
          // 1. Interactive Header (Backdrop / YouTube Player)
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isInWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                    color: _isInWatchlist ? AppColors.accentYellow : Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: _isInWatchlist ? 'Hapus dari Watchlist' : 'Simpan ke Watchlist',
                onPressed: _toggleWatchlist,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _isPlayingTrailer && _youtubeController != null
                  ? YoutubePlayer(
                      controller: _youtubeController!,
                      aspectRatio: 16 / 9,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Backdrop Image
                        if (backdropUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: backdropUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                            errorWidget: (_, __, ___) => Container(color: AppColors.surfaceCard),
                          )
                        else
                          Container(color: AppColors.surfaceElevated),

                        // Gradient Fade
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                                AppColors.backgroundPrimary.withValues(alpha: 0.7),
                                AppColors.backgroundPrimary,
                              ],
                              stops: const [0.0, 0.3, 0.8, 1.0],
                            ),
                          ),
                        ),

                        // Play Trailer Button Overlay
                        Center(
                          child: _activeVideoKey != null
                              ? GestureDetector(
                                  onTap: () => _playVideo(_activeVideoKey!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: AppColors.accentYellow, width: 1.5),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: AppColors.accentYellow, size: 28),
                                        SizedBox(width: 8),
                                        Text(
                                          'Putar Trailer Resmi',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Trailer Tidak Tersedia',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
          ),

          // 2. Movie Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _detail?.title ?? widget.movie.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  // Tagline
                  if (_detail?.tagline.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${_detail!.tagline}"',
                      style: const TextStyle(
                        color: AppColors.accentYellow,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Metadata Row (Release Year, Duration, Rating)
                  Row(
                    children: [
                      // Release Year
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _detail?.releaseYear ?? widget.movie.releaseYear,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Duration
                      if (_detail != null && _detail!.runtime > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _detail!.formattedDuration,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Banana Meter Score Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: score.color.withValues(alpha: 0.6), width: 1),
                        ),
                        child: Row(
                          children: [
                            Text(score.icon, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text(
                              '${score.percentage}% ${score.label}',
                              style: TextStyle(
                                color: score.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Genre Chips
                  if (_detail?.genres.isNotEmpty == true) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _detail!.genres.map((g) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExploreFilterPage(initialGenreId: g.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.inputBorder),
                            ),
                            child: Text(
                              g.name,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sinopsis
                  const Text(
                    'Sinopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_detail?.overview.isNotEmpty == true ? _detail!.overview : widget.movie.overview).isNotEmpty
                        ? (_detail?.overview.isNotEmpty == true ? _detail!.overview : widget.movie.overview)
                        : 'Belum ada sinopsis untuk film ini.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Daftar Video & Klip Tambahan
                  if (_detail != null && _detail!.videos.isNotEmpty) ...[
                    const Text(
                      '🎬 Video & Klip Tambahan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _detail!.videos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final video = _detail!.videos[index];
                          final isSelected = _activeVideoKey == video.key;

                          return GestureDetector(
                            onTap: () => _playVideo(video.key),
                            child: Container(
                              width: 170,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.accentYellow : AppColors.inputBorder,
                                  width: isSelected ? 1.5 : 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: isSelected ? AppColors.accentYellow : Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          video.type,
                                          style: TextStyle(
                                            color: isSelected ? AppColors.accentYellow : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    video.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    video.site,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Pemeran Utama (Cast)
                  if (_detail != null && _detail!.cast.isNotEmpty) ...[
                    const Text(
                      '👥 Pemeran Utama',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 155,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _detail!.cast.take(15).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final actor = _detail!.cast[index];

                          return SizedBox(
                            width: 85,
                            child: Column(
                              children: [
                                // Foto Aktor
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(42),
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    color: AppColors.surfaceElevated,
                                    child: actor.profileUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: actor.profileUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                                            errorWidget: (_, __, ___) => const Icon(
                                              Icons.person_rounded,
                                              color: AppColors.textSecondary,
                                              size: 36,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.textSecondary,
                                            size: 36,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Nama Aktor
                                Text(
                                  actor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Karakter
                                Text(
                                  actor.character,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tombol Simpan Watchlist Besar di Bawah
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _toggleWatchlist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isInWatchlist ? AppColors.surfaceElevated : AppColors.accentYellow,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isInWatchlist ? AppColors.accentYellow : Colors.transparent,
                            width: 1,
                          ),
                        ),
                      ),
                      icon: Icon(
                        _isInWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                        color: _isInWatchlist ? AppColors.accentYellow : Colors.black,
                      ),
                      label: Text(
                        _isInWatchlist ? 'Tersimpan di Watchlist' : 'Simpan ke Watchlist',
                        style: TextStyle(
                          color: _isInWatchlist ? AppColors.accentYellow : Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
