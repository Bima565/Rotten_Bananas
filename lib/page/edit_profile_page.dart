import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../components/banana_avatar_painter.dart';
import '../components/user_avatar_view.dart';
import '../core/app_colors.dart';
import '../core/password_hasher.dart';
import '../data/local/database_helper.dart';
import '../data/models/genre_model.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  String _selectedAvatarPath = 'banana_3d';
  List<int> _selectedGenreIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio);

    // Jika user sudah memiliki avatarPath, gunakan itu; jika belum, default ke 'banana_3d'
    if (widget.user.avatarPath != null && widget.user.avatarPath!.isNotEmpty) {
      _selectedAvatarPath = widget.user.avatarPath!;
    } else {
      _selectedAvatarPath = 'banana_3d';
    }

    // Parse genre aktif
    final rawGenres = widget.user.favoriteGenres;
    for (final part in rawGenres.split(',')) {
      final id = int.tryParse(part.trim());
      if (id != null) {
        _selectedGenreIds.add(id);
      } else {
        final match = GenreModel.defaultGenres.where(
          (g) => g.name.toLowerCase() == part.trim().toLowerCase(),
        );
        if (match.isNotEmpty) _selectedGenreIds.add(match.first.id);
      }
    }
    if (_selectedGenreIds.isEmpty) {
      _selectedGenreIds = [28, 878]; // Default Action (28), Sci-Fi (878)
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _getInitials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'BP';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'BP';
  }

  // Pilih foto dari Kamera
  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (image != null) {
        setState(() {
          _selectedAvatarPath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.statusFresh,
              content: Text('Foto dari kamera berhasil dipilih! 📸'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusRotten,
            content: Text('Gagal membuka kamera: $e'),
          ),
        );
      }
    }
  }

  // Pilih foto dari Galeri
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (image != null) {
        setState(() {
          _selectedAvatarPath = image.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.statusFresh,
              content: Text('Foto dari galeri berhasil dipilih! 🖼️'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusRotten,
            content: Text('Gagal membuka galeri: $e'),
          ),
        );
      }
    }
  }

  // Dialog Ganti Password (Hash SHA-256 lokal)
  Future<void> _showChangePasswordDialog() async {
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
                    'Ganti Password Akun',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password baru akan di-hash secara aman menggunakan SHA-256 lokal SQLite.',
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

                    final passwordHash = PasswordHasher.hash(newPass);
                    await _dbHelper.updateUserPassword(
                      email: widget.user.email,
                      passwordHash: passwordHash,
                    );

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

  // Bottom Sheet untuk ganti foto dari Kamera / Galeri
  Future<void> _showPhotoPickerSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ganti Foto Profil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accentYellow),
                  title: const Text('Ambil Foto dari Kamera', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.accentYellow),
                  title: const Text('Pilih dari Galeri', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Simpan Perubahan Profil
  Future<void> _saveProfile() async {
    final newFullName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim().replaceAll('@', '');
    final newBio = _bioController.text.trim();
    final newGenres = _selectedGenreIds.join(',');

    if (newFullName.isEmpty || newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusRotten,
          content: Text('Nama Lengkap dan Username tidak boleh kosong!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Simpan ke SQLite Lokal
      await _dbHelper.updateUserProfile(
        email: widget.user.email,
        fullName: newFullName,
        username: newUsername,
        bio: newBio,
        favoriteGenres: newGenres,
        avatarPath: _selectedAvatarPath,
      );

      // 2. Sinkronkan ke Firebase Auth / Cloud Firestore
      await _authService.updateUserProfile(
        fullName: newFullName,
        username: newUsername,
        bio: newBio,
        favoriteGenres: newGenres,
        avatarPath: _selectedAvatarPath,
      );

      final updatedUser = widget.user.copyWith(
        fullName: newFullName,
        username: newUsername,
        bio: newBio,
        favoriteGenres: newGenres,
        avatarPath: _selectedAvatarPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusFresh,
          content: Text('Perubahan profil berhasil disimpan! ✨'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusRotten,
          content: Text('Gagal menyimpan profil: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials();

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
        title: const Text(
          'Edit Profil Pribadi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Simpan',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar Preview Besar dengan Badge Kamera
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: GestureDetector(
                  onTap: _showPhotoPickerSheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatarView(
                        avatarPath: _selectedAvatarPath,
                        initials: initials,
                        size: 96,
                        borderWidth: 2.5,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.accentYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.backgroundPrimary, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.black,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Sub-header: Pilih Avatar Pisang:
            const Text(
              'Pilih Avatar Pisang:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Baris 6 Avatar Pisang Karakter
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: BananaCharacters.list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = BananaCharacters.list[index];
                  final isSelected = _selectedAvatarPath == item.key;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatarPath = item.key;
                      });
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF13151D),
                        border: Border.all(
                          color: isSelected ? AppColors.accentYellow : AppColors.inputBorder,
                          width: isSelected ? 2.8 : 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: CustomPaint(
                          size: const Size(52, 52),
                          painter: BananaPainter(character: item.character),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            // 4. Form Input: Nama Lengkap
            _buildFieldLabel('Nama Lengkap'),
            const SizedBox(height: 6),
            _buildInputField(
              controller: _nameController,
              hintText: 'Nama lengkap Anda',
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // 5. Form Input: Username
            _buildFieldLabel('Username'),
            const SizedBox(height: 6),
            _buildInputField(
              controller: _usernameController,
              hintText: 'Masukan Username',
            ),

            const SizedBox(height: 16),

            // 6. Form Input: Bio Singkat
            _buildFieldLabel('Bio Singkat'),
            const SizedBox(height: 6),
            _buildInputField(
              controller: _bioController,
              hintText: 'Tuliskan bio profil Anda...',
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // 7. Genre Favorit Akun:
            const Text(
              'Genre Favorit Akun:',
              style: TextStyle(
                color: AppColors.accentYellow,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: GenreModel.defaultGenres.map((genre) {
                  final isSelected = _selectedGenreIds.contains(genre.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
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
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppColors.accentYellow : AppColors.inputBorder,
                        ),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedGenreIds.add(genre.id);
                          } else {
                            _selectedGenreIds.remove(genre.id);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 8. Ganti Password Tile
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder, width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showChangePasswordDialog,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ganti Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 9. Tombol Bawah: Simpan Perubahan
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentYellow, width: 1.2),
        ),
      ),
    );
  }
}
