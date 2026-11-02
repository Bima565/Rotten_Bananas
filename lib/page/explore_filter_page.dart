import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_colors.dart';
import '../core/banana_score_helper.dart';
import '../core/debouncer.dart';
import '../data/models/genre_model.dart';
import '../data/models/movie_model.dart';
import '../data/services/tmdb_service.dart';
import 'movie_detail_page.dart';

class ExploreFilterPage extends StatefulWidget {
  final int? initialGenreId;

  const ExploreFilterPage({
    super.key,
    this.initialGenreId,
  });

  @override
  State<ExploreFilterPage> createState() => _ExploreFilterPageState();
}

class _ExploreFilterPageState extends State<ExploreFilterPage> {
  final TmdbService _tmdbService = TmdbService();
  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MovieModel> _movies = [];
  List<GenreModel> _genres = [];
  int _selectedGenreId = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _selectedGenreId = widget.initialGenreId ?? 0;
    _scrollController.addListener(_onScroll);
    _loadGenresAndMovies();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _searchOrDiscover(page: _currentPage + 1);
      }
    }
  }

  Future<void> _loadGenresAndMovies() async {
    setState(() => _isLoading = true);
    final genres = await _tmdbService.getGenres();
    if (mounted) {
      setState(() {
        _genres = [
          const GenreModel(id: 0, name: 'Semua'),
          ...genres,
        ];
      });
    }
    await _searchOrDiscover(page: 1);
  }

  Future<void> _searchOrDiscover({required int page, bool isRefresh = false}) async {
    final query = _searchController.text.trim();

    if (page == 1 && !isRefresh) {
      setState(() => _isLoading = true);
    } else if (page > 1) {
      setState(() => _isLoadingMore = true);
    }

    try {
      List<MovieModel> results = [];
      if (query.isNotEmpty) {
        results = await _tmdbService.searchMovies(query, page: page);
      } else if (_selectedGenreId != 0) {
        results = await _tmdbService.getMoviesByGenre(genreId: _selectedGenreId, page: page);
      } else {
        results = await _tmdbService.getPopularMovies(page: page);
      }

      if (!mounted) return;

      setState(() {
        if (isRefresh || page == 1) {
          _movies.clear();
        }

        final existingIds = _movies.map((m) => m.id).toSet();
        for (final m in results) {
          if (!existingIds.contains(m.id)) {
            _movies.add(m);
            existingIds.add(m.id);
          }
        }

        _currentPage = page;
        _hasMore = results.isNotEmpty;
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

  void _onSearchChanged(String value) {
    _debouncer.run(() {
      _searchOrDiscover(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Eksplor & Cari Film',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
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
      body: Column(
        children: [
          // 1. Search Bar (Debounced 500ms)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceCard,
                hintText: 'Ketik judul film atau kata kunci...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentYellow, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _searchOrDiscover(page: 1);
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentYellow, width: 1.2),
                ),
              ),
            ),
          ),

          // 2. Genre Chips (Horizontal Scroll)
          if (_genres.isNotEmpty) ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _genres.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final genre = _genres[index];
                  final isSelected = _selectedGenreId == genre.id;
                  return ChoiceChip(
                    label: Text(genre.name),
                    selected: isSelected,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    selectedColor: AppColors.accentYellow,
                    backgroundColor: AppColors.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isSelected ? AppColors.accentYellow : AppColors.inputBorder,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedGenreId = selected ? genre.id : 0;
                      });
                      _searchOrDiscover(page: 1);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Movie Results (Grid / List)
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentYellow,
              backgroundColor: AppColors.surfaceCard,
              onRefresh: () => _searchOrDiscover(page: 1, isRefresh: true),
              child: _isLoading
                  ? _buildShimmerLoading()
                  : _movies.isEmpty
                      ? _buildEmptyState()
                      : _isGridView
                          ? _buildGridView()
                          : _buildListView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: _movies.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          return _buildShimmerItem();
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

                        // Banana Score Badge
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

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            height: 115,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder, width: 0.8),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                  child: SizedBox(
                    width: 80,
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

  Widget _buildShimmerLoading() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _buildShimmerItem(),
    );
  }

  Widget _buildShimmerItem() {
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.textSecondary, size: 54),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada film yang cocok.',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba gunakan kata kunci lain atau pilih genre yang berbeda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
