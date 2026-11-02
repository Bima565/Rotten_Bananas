import 'package:flutter/material.dart';
import 'app_colors.dart';

class BananaScoreInfo {
  final int percentage;
  final String label;
  final String icon;
  final Color color;

  const BananaScoreInfo({
    required this.percentage,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class BananaScoreHelper {
  static BananaScoreInfo calculate(double voteAverage) {
    final percentage = (voteAverage * 10).round().clamp(0, 100);
    if (percentage >= 75) {
      return BananaScoreInfo(
        percentage: percentage,
        label: 'Golden Ripe',
        icon: '🍌',
        color: AppColors.statusFresh,
      );
    } else if (percentage >= 55) {
      return BananaScoreInfo(
        percentage: percentage,
        label: 'Bruised',
        icon: '🍌',
        color: AppColors.statusBruised,
      );
    } else {
      return BananaScoreInfo(
        percentage: percentage,
        label: 'Rotten Bananas',
        icon: '🤢',
        color: AppColors.statusRotten,
      );
    }
  }
}
