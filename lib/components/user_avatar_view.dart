import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'banana_avatar_painter.dart';

class UserAvatarView extends StatelessWidget {
  final String? avatarPath;
  final String initials;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;

  const UserAvatarView({
    super.key,
    required this.avatarPath,
    required this.initials,
    this.size = 90,
    this.borderWidth = 2.2,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.accentYellow;

    Widget content;

    if (avatarPath != null && avatarPath!.isNotEmpty) {
      final path = avatarPath!;

      // 1. Cek Karakter Banana Preset (banana_3d, banana_cool, dsb.)
      if (path.startsWith('banana_')) {
        BananaCharacter character;
        switch (path) {
          case 'banana_3d':
            character = BananaCharacter.cinema3d;
            break;
          case 'banana_cool':
            character = BananaCharacter.cool;
            break;
          case 'banana_googly':
            character = BananaCharacter.googly;
            break;
          case 'banana_rotten':
            character = BananaCharacter.rotten;
            break;
          case 'banana_chef':
            character = BananaCharacter.chef;
            break;
          case 'banana_classic':
          default:
            character = BananaCharacter.classic;
            break;
        }

        content = Container(
          color: const Color(0xFF13151D),
          child: CustomPaint(
            size: Size(size, size),
            painter: BananaPainter(character: character),
          ),
        );
      }
      // 2. Cek Initial Preset (misal 'preset_BP')
      else if (path.startsWith('preset_')) {
        final code = path.replaceFirst('preset_', '');
        content = Container(
          color: const Color(0xFF13151D),
          child: Center(
            child: Text(
              code,
              style: TextStyle(
                color: AppColors.accentYellow,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }
      // 3. Cek Foto Lokal dari Kamera / Galeri
      else if (!path.startsWith('http://') && !path.startsWith('https://')) {
        final file = File(path);
        if (file.existsSync()) {
          content = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultBanana(),
          );
        } else {
          content = _buildDefaultBanana();
        }
      }
      // 4. Cek Foto Online (misal Google photoURL)
      else {
        content = CachedNetworkImage(
          imageUrl: path,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppColors.surfaceElevated),
          errorWidget: (_, __, ___) => _buildDefaultBanana(),
        );
      }
    } else {
      // Default jika belum ada avatar yang dipilih: Pisang 3D Cinema
      content = _buildDefaultBanana();
    }

    final avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF13151D),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipOval(child: content),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }
    return avatarWidget;
  }

  Widget _buildDefaultBanana() {
    return Container(
      color: const Color(0xFF13151D),
      child: CustomPaint(
        size: Size(size, size),
        painter: BananaPainter(character: BananaCharacter.cinema3d),
      ),
    );
  }
}
