import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_colors.dart';
import '../core/banana_score_helper.dart';
import '../data/models/genre_model.dart';
import '../data/models/movie_model.dart';
import '../data/services/auth_service.dart';
import '../data/services/tmdb_service.dart';
import '../data/services/watchlist_service.dart';
import 'category_movies_page.dart';
import 'explore_filter_page.dart';
import 'login.dart';
import 'movie_detail_page.dart';
import 'watchlist_page.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  final TmdbService _tmdbService = TmdbService();
  final AuthService _authService = AuthService();
  final WatchlistService _watchlistService = WatchlistService();

  String _userName = 'Penggemar Film';
  int _currentNavIndex = 0;
  int _selectedGenreId = 0; // 0 = Semua
  int _carouselIndex = 0;

  bool _isLoading = true;
  List<MovieModel> _trendingMovies = [];
  List<MovieModel> _nowPlayingMovies = [];
  List<MovieModel> _popularMovies = [];
  List<MovieModel> _topRatedMovies = [];
  List<MovieModel> _upcomingMovies = [];
  List<GenreModel> _genres = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _userName = user.fullName.split(' ').first;
      });
    }

    try {
      final results = await Future.wait([
        _tmdbService.getTrendingMovies(),
        _tmdbService.getNowPlayingMovies(),
        _tmdbService.getPopularMovies(),
        _tmdbService.getTopRatedMovies(),
        _tmdbService.getUpcomingMovies(),
        _tmdbService.getGenres(),
      ]);

      if (!mounted) return;

      setState(() {
        _trendingMovies = results[0] as List<MovieModel>;
        _nowPlayingMovies = results[1] as List<MovieModel>;
        _popularMovies = results[2] as List<MovieModel>;
        _topRatedMovies = results[3] as List<MovieModel>;
        _upcomingMovies = results[4] as List<MovieModel>;
        _genres = [
          const GenreModel(id: 0, name: 'Semua'),
          ...(results[5] as List<GenreModel>),
        ];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<MovieModel> _filterByGenre(List<MovieModel> movies) {
    if (_selectedGenreId == 0) return movies;
    return movies.where((m) => m.genreIds.contains(_selectedGenreId)).toList();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Keluar Akun', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusRotten),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
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
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/logo_app.png',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ROTTEN BANANAS',
              style: TextStyle(
                color: AppColors.accentYellow,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Halo, $_userName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleLogout,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.accentYellow,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.accentYellow,
        backgroundColor: AppColors.surfaceCard,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar Trigger
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExploreFilterPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppColors.accentYellow, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Cari film, trailer, atau genre...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Hero Trending Carousel Banner (16:9)
              if (_isLoading)
                _buildShimmerCarousel()
              else if (_trendingMovies.isNotEmpty)
                _buildTrendingCarousel(),

              const SizedBox(height: 18),

              // Kategori / Genre Cepat (Horizontal Chips)
              if (_genres.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🗂️ Kategori Cepat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_selectedGenreId != 0)
                        GestureDetector(
                          onTap: () {
                            final genre = _genres.firstWhere((g) => g.id == _selectedGenreId);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryMoviesPage(
                                  title: 'Kategori: ${genre.name}',
                                  categoryType: CategoryType.genre,
                                  genreId: genre.id,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Lihat Semua >',
                            style: TextStyle(
                              color: AppColors.accentYellow,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Section 1: Sedang Tayang di Bioskop (Now Playing)
              _buildMovieSection(
                title: '🎬 Sedang Tayang di Bioskop',
                movies: _filterByGenre(_nowPlayingMovies),
                isLoading: _isLoading,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryMoviesPage(
                        title: '🎬 Sedang Tayang di Bioskop',
                        categoryType: CategoryType.nowPlaying,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Section 2: Paling Populer (Popular)
              _buildMovieSection(
                title: '🍿 Paling Populer',
                movies: _filterByGenre(_popularMovies),
                isLoading: _isLoading,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryMoviesPage(
                        title: '🍿 Paling Populer',
                        categoryType: CategoryType.popular,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Section 3: Rating Tertinggi (Top Rated)
              _buildMovieSection(
                title: '⭐ Rating Tertinggi',
                movies: _filterByGenre(_topRatedMovies),
                isLoading: _isLoading,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryMoviesPage(
                        title: '⭐ Rating Tertinggi',
                        categoryType: CategoryType.topRated,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Section 4: Segera Tayang (Upcoming)
              _buildMovieSection(
                title: '📅 Segera Tayang di Bioskop',
                movies: _filterByGenre(_upcomingMovies),
                isLoading: _isLoading,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryMoviesPage(
                        title: '📅 Segera Tayang di Bioskop',
                        categoryType: CategoryType.upcoming,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.inputBorder, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExploreFilterPage()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchlistPage()),
              );
            } else if (index == 3) {
              _handleLogout();
            } else {
              setState(() => _currentNavIndex = index);
            }
          },
          backgroundColor: AppColors.surfaceCard,
          selectedItemColor: AppColors.accentYellow,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Eksplor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_outline_rounded),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  // --- Hero Trending Carousel ---
  Widget _buildTrendingCarousel() {
    final bannerMovies = _trendingMovies.take(5).toList();
    if (bannerMovies.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: bannerMovies.length,
          options: CarouselOptions(
            height: 215,
            viewportFraction: 0.92,
            enlargeCenterPage: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            onPageChanged: (index, reason) {
              setState(() {
                _carouselIndex = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final movie = bannerMovies[index];
            final score = BananaScoreHelper.calculate(movie.voteAverage);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceElevated),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    // Backdrop Image
                    if (movie.backdropUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: movie.backdropUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceCard,
                          child: const Center(
                            child: Icon(Icons.movie_filter_rounded, color: AppColors.textSecondary, size: 40),
                          ),
                        ),
                      )
                    else
                      Container(color: AppColors.surfaceElevated),

                    // Dark Cinema Gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.backgroundPrimary.withValues(alpha: 0.3),
                            AppColors.backgroundPrimary.withValues(alpha: 0.85),
                            AppColors.backgroundPrimary,
                          ],
                          stops: const [0.0, 0.4, 0.75, 1.0],
                        ),
                      ),
                    ),

                    // Info Overlay
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Banana Score Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: score.color.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(score.icon, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  '${score.percentage}% ${score.label}',
                                  style: TextStyle(
                                    color: score.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Movie Title & Year
                          Text(
                            '${movie.title} (${movie.releaseYear})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Trailer & Watchlist buttons
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentYellow,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                                label: const Text(
                                  'Tonton Trailer',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.accentYellow, width: 1),
                                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.accentYellow, size: 16),
                                label: const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    color: AppColors.accentYellow,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    final isSaved = await _watchlistService.toggleWatchlist(movie);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: isSaved ? AppColors.statusFresh : AppColors.surfaceCard,
                                        content: Text(
                                          isSaved
                                              ? 'Film "${movie.title}" disimpan ke Watchlist! 🔖'
                                              : 'Film dihapus dari Watchlist.',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.statusRotten,
                                        content: Text(e.toString().replaceAll('Exception: ', '')),
                                      ),
                                    );
                                  }
                                },
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
      ),
        const SizedBox(height: 10),
        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(bannerMovies.length, (index) {
            final isActive = _carouselIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentYellow : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // --- Horizontal Movie Section ---
  Widget _buildMovieSection({
    required String title,
    required List<MovieModel> movies,
    required bool isLoading,
    VoidCallback? onSeeAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text(
                  'Lihat Semua >',
                  style: TextStyle(
                    color: AppColors.accentYellow,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal List of 2:3 Poster Cards
        SizedBox(
          height: 240,
          child: isLoading
              ? _buildShimmerPosterList()
              : movies.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada film untuk kategori ini.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: movies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final movie = movies[index];
                        final score = BananaScoreHelper.calculate(movie.voteAverage);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)),
                            );
                          },
                          child: SizedBox(
                            width: 130,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Poster Card with Aspect Ratio 2:3
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.inputBorder),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (movie.posterUrl.isNotEmpty)
                                          CachedNetworkImage(
                                            imageUrl: movie.posterUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
                                            errorWidget: (_, __, ___) => const Center(
                                              child: Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                                            ),
                                          )
                                        else
                                          const Center(
                                            child: Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                                          ),

                                        // Banana Rating Badge Overlay (Top Left)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.82),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: score.color.withValues(alpha: 0.6),
                                                width: 0.8,
                                              ),
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
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Movie Title
                              Text(
                                movie.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              // Release Year
                              Text(
                                movie.releaseYear.isNotEmpty ? movie.releaseYear : 'N/A',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    ),
        ),
      ],
    );
  }

  // --- Shimmer Loading Placeholders ---
  Widget _buildShimmerCarousel() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceCard,
      highlightColor: AppColors.surfaceElevated,
      child: Container(
        height: 215,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildShimmerPosterList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.surfaceCard,
        highlightColor: AppColors.surfaceElevated,
        child: Container(
          width: 130,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
