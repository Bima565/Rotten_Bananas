import 'dart:async';
import 'package:flutter/material.dart';
import '../components/user_avatar_view.dart';
import '../core/app_colors.dart';
import '../core/password_hasher.dart';
import '../data/local/database_helper.dart';
import '../data/models/genre_model.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_service.dart';
import '../data/services/watchlist_service.dart';
import 'edit_profile_page.dart';
import 'login.dart';
import 'watchlist_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onNavigateToWatchlist;

  const ProfilePage({super.key, this.onNavigateToWatchlist});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final WatchlistService _watchlistService = WatchlistService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  StreamSubscription? _watchlistSubscription;
  UserModel? _currentUser;
  int _watchlistCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();

    // Dengarkan perubahan watchlist secara realtime agar counter selalu akurat
    _watchlistSubscription = _watchlistService.getWatchlistStream().listen((movies) {
      if (mounted) {
        setState(() {
          _watchlistCount = movies.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _watchlistSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Ambil data user dari AuthService (Firebase / Session)
      UserModel? user = await _authService.getCurrentUser();

      // 2. Cek SQLite Lokal
      if (user != null && user.email.isNotEmpty) {
        final localUser = await _dbHelper.getUserByEmail(user.email);
        if (localUser != null) {
          user = localUser;
        } else {
          // Simpan sinkronisasi awal ke SQLite
          await _dbHelper.saveOrUpdateUser(user);
        }
      } else {
        // Fallback coba ambil dari SQLite pertama jika ada
        user = await _dbHelper.getFirstUser();
      }

      // Default demo fallback jika belum ada data agar pas seperti mockup
      user ??= UserModel(
        fullName: 'Bima Prawira Dharma',
        username: 'bima_cinema',
        email: 'demo@overripe.app',
        bio: 'Pecinta film & pemburu trailer.',
        favoriteGenres: '28,878',
        avatarPath: 'banana_3d',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (user.avatarPath == null || user.avatarPath!.isEmpty) {
        user = user.copyWith(avatarPath: 'banana_3d');
      }

      // Simpan session & SQLite jika belum ada
      await _dbHelper.saveOrUpdateUser(user);

      // 3. Ambil jumlah Watchlist (dari Firestore / SQLite)
      final count = await _watchlistService.getWatchlistCount();

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _watchlistCount = count;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Navigasi langsung ke Tampilan Watchlist
  void _navigateToWatchlist() {
    if (widget.onNavigateToWatchlist != null) {
      widget.onNavigateToWatchlist!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WatchlistPage()),
      );
    }
  }

  // Dapatkan daftar genre favorit yang dipilih
  List<GenreModel> _getSelectedGenres() {
    final raw = _currentUser?.favoriteGenres ?? '';
    if (raw.trim().isEmpty) return [];

    final result = <GenreModel>[];
    for (final part in raw.split(',')) {
      final id = int.tryParse(part.trim());
      if (id != null) {
        final match = GenreModel.defaultGenres.where((g) => g.id == id);
        if (match.isNotEmpty) {
          result.add(match.first);
        }
      } else {
        final match = GenreModel.defaultGenres.where(
          (g) => g.name.toLowerCase() == part.trim().toLowerCase(),
        );
        if (match.isNotEmpty) {
          result.add(match.first);
        }
      }
    }
    return result;
  }

  // Tampilkan Pop-up Genre Favorit Saya
  Future<void> _showFavoriteGenresDialog() async {
    final genres = _getSelectedGenres();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.movie_filter_rounded, color: AppColors.statusFresh, size: 22),
            SizedBox(width: 8),
            Text(
              'Genre Favorit Akun',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              genres.isNotEmpty
                  ? 'Daftar genre pilihan yang disukai untuk rekomendasi film Anda:'
                  : 'Anda belum memilih genre favorit.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (genres.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genres.map((g) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.statusFresh.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.statusFresh, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          g.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.accentYellow, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pilih genre di Edit Profil agar Rotten Bananas dapat merekomendasikan film sesuai selera!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToEditProfile();
            },
            child: const Text(
              'Ubah Genre',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'BP';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'BP';
  }

  String _getGenreNames(String favoriteGenres) {
    if (favoriteGenres.trim().isEmpty) return 'Action, Sci-Fi';

    // Jika tersimpan sebagai ID: "28,878"
    final ids = favoriteGenres
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();

    if (ids.isNotEmpty) {
      final names = ids.map((id) {
        final match = GenreModel.defaultGenres.where((g) => g.id == id);
        return match.isNotEmpty ? match.first.name : null;
      }).whereType<String>().toList();

      if (names.isNotEmpty) return names.join(', ');
    }

    // Jika tersimpan sebagai nama string langsung
    return favoriteGenres;
  }

  // Buka Halaman Edit Profil Mandiri
  Future<void> _navigateToEditProfile() async {
    if (_currentUser == null) return;
    final updatedUser = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: _currentUser!),
      ),
    );

    if (updatedUser != null && mounted) {
      setState(() {
        _currentUser = updatedUser;
      });
    }
  }

  // Dialog Ubah Password Akun (Hash SHA-256 lokal)
  Future<void> _showChangePasswordDialog() async {
    if (_currentUser == null) return;

    final passController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscurePass = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.inputBorder),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: AppColors.accentYellow, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ubah Password Akun',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password baru akan di-hash secara aman menggunakan algoritma SHA-256 lokal (SQLite).',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: obscurePass,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final newPass = passController.text.trim();
                    final confirmPass = confirmPassController.text.trim();

                    if (newPass.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.statusRotten,
                          content: Text('Password minimal 6 karakter!'),
                        ),
                      );
                      return;
                    }

                    if (newPass != confirmPass) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.statusRotten,
                          content: Text('Konfirmasi password tidak cocok!'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    // 1. Hash password dengan SHA-256
                    final passwordHash = PasswordHasher.hash(newPass);

                    // 2. Simpan hash ke SQLite
                    await _dbHelper.updateUserPassword(
                      email: _currentUser!.email,
                      passwordHash: passwordHash,
                    );

                    // 3. Update password di Firebase Auth jika terhubung
                    try {
                      await _authService.setAccountPassword(newPass);
                    } catch (_) {}

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.statusFresh,
                        content: Text(
                          'Password berhasil diubah!\nSHA-256: ${passwordHash.substring(0, 16)}...',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  child: const Text('Simpan Password', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog Bersihkan Seluruh Watchlist (Reset SQLite & Firestore)
  Future<void> _showClearWatchlistDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.statusRotten, size: 24),
            SizedBox(width: 8),
            Text(
              'Bersihkan Watchlist?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          'Tindakan ini akan mengosongkan seluruh tabel watchlist di SQLite lokal dan akun Anda. Aksi ini tidak dapat dibatalkan.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRotten,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Watchlist', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _watchlistService.clearAllWatchlist();
      setState(() {
        _watchlistCount = 0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Seluruh data watchlist SQLite berhasil dibersihkan! 🗑️'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Handle Logout
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        title: const Text('Keluar Akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun ini?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRotten,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentYellow),
        ),
      );
    }

    final user = _currentUser ??
        UserModel(
          fullName: 'Bima Prawira Dharma',
          username: 'bima_cinema',
          email: 'demo@overripe.app',
          bio: 'Pecinta film & pemburu trailer.',
          favoriteGenres: '28,878',
          avatarPath: 'banana_3d',
          createdAt: '',
          updatedAt: '',
        );

    final initials = _getInitials(user.fullName);
    final genreDisplay = _getGenreNames(user.favoriteGenres);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentYellow,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: _loadProfileData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Profil Saya & Edit Profil Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profil Saya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.inputBorder, width: 1.2),
                        backgroundColor: AppColors.surfaceCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _navigateToEditProfile,
                      child: const Text(
                        'Edit Profil',
                        style: TextStyle(
                          color: AppColors.accentYellow,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Main Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.inputBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Avatar dengan Border Kuning & Badge Kamera
                      GestureDetector(
                        onTap: _navigateToEditProfile,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserAvatarView(
                              avatarPath: user.avatarPath,
                              initials: initials,
                              size: 86,
                              borderWidth: 2.2,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.accentYellow,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surfaceCard, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.black,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Nama Lengkap
                      Text(
                        user.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Username
                      Text(
                        '@${user.username}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.accentYellow,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Bio Quoted
                      Text(
                        '"${user.bio}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Email
                      Text(
                        user.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Stats Row (2 Cards)
                Row(
                  children: [
                    // Card 1: Watchlist Count (Tappable -> Langsung ke Watchlist)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.inputBorder, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _navigateToWatchlist,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_watchlistCount Film',
                                    style: const TextStyle(
                                      color: AppColors.accentYellow,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Di Watchlist Saya',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Card 2: Favorite Genres (Tappable -> Pop-up Genre Favorit)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.inputBorder, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _showFavoriteGenresDialog,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    genreDisplay,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.statusFresh,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Genre Favorit Akun',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Section Title: Pengaturan Akun Pribadi
                const Text(
                  'Pengaturan Akun Pribadi',
                  style: TextStyle(
                    color: AppColors.accentYellow,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 10),

                // 5. Settings Action Tiles
                // Tile 1: Ubah Data Profil
                _buildActionTile(
                  title: 'Ubah Data Profil (Nama, Bio, Genre)',
                  onTap: _navigateToEditProfile,
                ),

                const SizedBox(height: 8),

                // Tile 2: Ubah Password Akun
                _buildActionTile(
                  title: 'Ubah Password Akun',
                  onTap: _showChangePasswordDialog,
                ),

                const SizedBox(height: 8),

                // Tile 3: Bersihkan Seluruh Watchlist
                _buildActionTile(
                  title: 'Bersihkan Seluruh Watchlist',
                  onTap: _showClearWatchlistDialog,
                ),

                const SizedBox(height: 16),

                // 6. Attribution Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.inputBorder),
                            ),
                            title: const Text(
                              'TMDb API Attribution',
                              style: TextStyle(color: AppColors.accentYellow, fontWeight: FontWeight.w800),
                            ),
                            content: const Text(
                              'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Tutup', style: TextStyle(color: AppColors.accentYellow)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Center(
                          child: Text(
                            'TMDb API Attribution',
                            style: TextStyle(
                              color: AppColors.accentYellow,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 7. Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.statusRotten, width: 1.2),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleLogout,
                    child: const Text(
                      'Keluar Akun (Logout)',
                      style: TextStyle(
                        color: AppColors.statusRotten,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
