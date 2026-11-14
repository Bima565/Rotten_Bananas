import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Ikon badge status ulasan menggunakan ikon bawaan Flutter (Material Icons)
/// dengan karakter dan warna khas untuk masing-masing tingkatan rating:
/// - 5 Bintang (Sangat Bagus): Icons.workspace_premium_rounded (Piala / Medali Emas)
/// - 4 Bintang (Bagus): Icons.verified_rounded (Lencana Segar Terverifikasi)
/// - 3 Bintang (Lumayan): Icons.thumbs_up_down_rounded (Timbang Rasa / Seimbang)
/// - 2 Bintang (Kurang): Icons.warning_amber_rounded (Peringatan Kualitas Turun)
/// - 1 Bintang (Buruk): Icons.heart_broken_rounded (Film Mengecewakan / Flop)
class BananaStatusIcon extends StatelessWidget {
  final double rating;
  final double size;

  const BananaStatusIcon({
    super.key,
    required this.rating,
    this.size = 16,
  });

  /// Mengambil IconData bawaan Flutter berdasarkan nilai rating
  static IconData getIcon(double rating) {
    if (rating >= 5.0) {
      return Icons.workspace_premium_rounded;
    } else if (rating >= 4.0) {
      return Icons.verified_rounded;
    } else if (rating >= 3.0) {
      return Icons.thumbs_up_down_rounded;
    } else if (rating >= 2.0) {
      return Icons.warning_amber_rounded;
    } else {
      return Icons.heart_broken_rounded;
    }
  }

  /// Mengambil warna tema khas berdasarkan nilai rating
  static Color getColor(double rating) {
    if (rating >= 5.0) {
      return AppColors.accentYellow;
    } else if (rating >= 4.0) {
      return AppColors.statusFresh;
    } else if (rating >= 3.0) {
      return AppColors.statusBruised;
    } else if (rating >= 2.0) {
      return const Color(0xFFE76F51);
    } else {
      return AppColors.statusRotten;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      getIcon(rating),
      size: size,
      color: getColor(rating),
    );
  }
}
