import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_colors.dart';
import '../core/banana_score_helper.dart';
import '../data/models/movie_model.dart';
import '../data/services/tmdb_service.dart';
import 'movie_detail_page.dart';

enum CategoryType {
  nowPlaying,
  popular,
  topRated,
  upcoming,
  genre,
}

class CategoryMoviesPage extends StatefulWidget {
  final String title;
  final CategoryType categoryType;
  final int? genreId;

  const CategoryMoviesPage({
    super.key,
    required this.title,
    required this.categoryType,
    this.genreId,
  });

  @override
  State<CategoryMoviesPage> createState() => _CategoryMoviesPageState();
}

class _CategoryMoviesPageState extends State<CategoryMoviesPage> {
  final TmdbService _tmdbService = TmdbService();
  final ScrollController _scrollController = ScrollController();

  final List<MovieModel> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _fetchMovies(page: 1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchMovies(page: _currentPage + 1);
      }
    }
  }

  Future<void> _fetchMovies({required int page, bool isRefresh = false}) async {
    if (page == 1 && !isRefresh) {
      setState(() => _isLoading = true);
    } else if (page > 1) {
      setState(() => _isLoadingMore = true);
    }

    try {
      List<MovieModel> newMovies = [];
      switch (widget.categoryType) {
        case CategoryType.nowPlaying:
          newMovies = await _tmdbService.getNowPlayingMovies(page: page);
          break;
        case CategoryType.popular:
          newMovies = await _tmdbService.getPopularMovies(page: page);
          break;
        case CategoryType.topRated:
          newMovies = await _tmdbService.getTopRatedMovies(page: page);
          break;
        case CategoryType.upcoming:
          newMovies = await _tmdbService.getUpcomingMovies(page: page);
          break;
        case CategoryType.genre:
          if (widget.genreId != null) {
            newMovies = await _tmdbService.getMoviesByGenre(
              genreId: widget.genreId!,
              page: page,
            );
          }
          break;
      }

      if (!mounted) return;

      setState(() {
        if (isRefresh || page == 1) {
          _movies.clear();
        }

        // Hindari duplikasi ID film
        final existingIds = _movies.map((m) => m.id).toSet();
        for (final m in newMovies) {
          if (!existingIds.contains(m.id)) {
            _movies.add(m);
            existingIds.add(m.id);
          }
        }

        _currentPage = page;
        _hasMore = newMovies.isNotEmpty;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.accentYellow,
              size: 22,
            ),
            tooltip: _isGridView ? 'Tampilan List' : 'Tampilan Grid',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentYellow,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: () => _fetchMovies(page: 1, isRefresh: true),
        child: _isLoading
            ? _buildShimmerLoading()
            : _movies.isEmpty
                ? _buildEmptyState()
                : _isGridView
                    ? _buildGridView()
                    : _buildListView(),
      ),
    );
  }

  // --- Grid View (2 Kolom Poster 2:3) ---
  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: _movies.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          return _buildShimmerPosterItem();
        }

        final movie = _movies[index];
        final score = BananaScoreHelper.calculate(movie.voteAverage);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Poster Image (Expanded)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (movie.posterUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                          ),
                        )
                      else
                        Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                        ),

                      // Banana Score Badge (Top Left)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: score.color.withValues(alpha: 0.6), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(score.icon, style: const TextStyle(fontSize: 10)),
                              const SizedBox(width: 3),
                              Text(
                                '${score.percentage}%',
                                style: TextStyle(
                                  color: score.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info Section
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            movie.releaseYear.isNotEmpty ? movie.releaseYear : 'N/A',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            score.label,
                            style: TextStyle(
                              color: score.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  // --- List View (Mode Baris / Horizontal Card) ---
  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _movies.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.accentYellow, strokeWidth: 2),
            ),
          );
        }

        final movie = _movies[index];
        final score = BananaScoreHelper.calculate(movie.voteAverage);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
            );
          },
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder, width: 0.8),
            ),
            child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                child: SizedBox(
                  width: 85,
                  height: double.infinity,
                  child: movie.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: movie.posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                        ),
                ),
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            movie.releaseYear.isNotEmpty ? movie.releaseYear : 'N/A',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      // Banana Score Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: score.color.withValues(alpha: 0.6), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(score.icon, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  '${score.percentage}% ${score.label}',
                                  style: TextStyle(
                                    color: score.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  // --- Shimmer Placeholders ---
  Widget _buildShimmerLoading() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _buildShimmerPosterItem(),
    );
  }

  Widget _buildShimmerPosterItem() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceCard,
      highlightColor: AppColors.surfaceElevated,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter_outlined, color: AppColors.textSecondary, size: 54),
          const SizedBox(height: 12),
          const Text(
            'Belum ada film untuk kategori ini.',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentYellow),
            onPressed: () => _fetchMovies(page: 1, isRefresh: true),
            child: const Text('Coba Lagi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
