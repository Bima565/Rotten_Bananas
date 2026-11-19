import 'package:flutter/material.dart';

enum BananaCharacter {
  cinema3d, // 1. Pisang Kacamata 3D (Cyan & Merah)
  cool,     // 2. Pisang Keren Kacamata Hitam
  googly,   // 3. Pisang Mata Belok Kartun
  rotten,   // 4. Pisang Busuk Rotten Cokelat
  chef,     // 5. Pisang Koki Topi Putih
  classic,  // 6. Pisang Klasik Ceria
}

class BananaAvatarData {
  final String key;
  final String name;
  final BananaCharacter character;

  const BananaAvatarData({
    required this.key,
    required this.name,
    required this.character,
  });
}

class BananaCharacters {
  static const List<BananaAvatarData> list = [
    BananaAvatarData(
      key: 'banana_3d',
      name: 'Pisang 3D Cinema',
      character: BananaCharacter.cinema3d,
    ),
    BananaAvatarData(
      key: 'banana_cool',
      name: 'Pisang Keren',
      character: BananaCharacter.cool,
    ),
    BananaAvatarData(
      key: 'banana_googly',
      name: 'Pisang Mata Kartun',
      character: BananaCharacter.googly,
    ),
    BananaAvatarData(
      key: 'banana_rotten',
      name: 'Pisang Rotten Busuk',
      character: BananaCharacter.rotten,
    ),
    BananaAvatarData(
      key: 'banana_chef',
      name: 'Pisang Koki',
      character: BananaCharacter.chef,
    ),
    BananaAvatarData(
      key: 'banana_classic',
      name: 'Pisang Klasik Ceria',
      character: BananaCharacter.classic,
    ),
  ];
}

class BananaAvatarWidget extends StatelessWidget {
  final BananaCharacter character;
  final double size;

  const BananaAvatarWidget({
    super.key,
    required this.character,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF13151D),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: BananaPainter(character: character),
        ),
      ),
    );
  }
}

class BananaPainter extends CustomPainter {
  final BananaCharacter character;

  BananaPainter({required this.character});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warna dasar pisang
    final isRotten = character == BananaCharacter.rotten;
    final bananaColor = isRotten ? const Color(0xFF5D4037) : const Color(0xFFFFD600);
    final bananaHighlight = isRotten ? const Color(0xFF6D4C41) : const Color(0xFFFFEA00);
    final bananaShadow = isRotten ? const Color(0xFF3E2723) : const Color(0xFFFFB300);
    final stemColor = isRotten ? const Color(0xFF2E1C14) : const Color(0xFF2E7D32);
    final tipColor = isRotten ? const Color(0xFF1E100A) : const Color(0xFF42210B);

    // 1. Gambar Bentuk Pisang (Crescent Banana)
    final bananaPath = Path();
    // Titik awal dari tangkai atas
    final stemX = w * 0.50;
    final stemY = h * 0.17;
    bananaPath.moveTo(stemX, stemY);

    // Lengkungan Luar (Punggung Pisang)
    bananaPath.cubicTo(
      w * 0.82, h * 0.28, // Control 1
      w * 0.84, h * 0.68, // Control 2
      w * 0.44, h * 0.85, // Ujung bawah
    );

    // Ujung bawah pisang
    bananaPath.lineTo(w * 0.40, h * 0.83);

    // Lengkungan Dalam (Perut Pisang)
    bananaPath.cubicTo(
      w * 0.62, h * 0.65, // Control 1
      w * 0.58, h * 0.35, // Control 2
      stemX - (w * 0.04), stemY + (h * 0.02),
    );
    bananaPath.close();

    // Gambar bayangan pisang
    final shadowPaint = Paint()
      ..color = bananaShadow
      ..style = PaintingStyle.fill;
    canvas.drawPath(bananaPath, shadowPaint);

    // Gambar badan utama pisang
    final mainPaint = Paint()
      ..color = bananaColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bananaPath, mainPaint);

    // Highlight lengkungan punggung pisang
    final highlightPath = Path();
    highlightPath.moveTo(w * 0.53, h * 0.22);
    highlightPath.cubicTo(w * 0.77, h * 0.32, w * 0.78, h * 0.64, w * 0.45, h * 0.82);
    final highlightPaint = Paint()
      ..color = bananaHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(highlightPath, highlightPaint);

    // Tangkai atas pisang
    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.fill;
    final stemRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.49, h * 0.16), width: w * 0.09, height: h * 0.07),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(stemRect, stemPaint);

    // Ujung bawah pisang (bintik cokelat)
    final tipPaint = Paint()
      ..color = tipColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.42, h * 0.84), w * 0.035, tipPaint);

    // 2. Gambar Aksesori & Wajah Unik Sesuai Karakter
    switch (character) {
      case BananaCharacter.cinema3d:
        _drawCinema3d(canvas, w, h);
        break;
      case BananaCharacter.cool:
        _drawCool(canvas, w, h);
        break;
      case BananaCharacter.googly:
        _drawGoogly(canvas, w, h);
        break;
      case BananaCharacter.rotten:
        _drawRotten(canvas, w, h);
        break;
      case BananaCharacter.chef:
        _drawChef(canvas, w, h);
        break;
      case BananaCharacter.classic:
        _drawClassic(canvas, w, h);
        break;
    }
  }

  // 1. Karakter Pisang Kacamata 3D (Cyan di Kiri, Merah di Kanan)
  void _drawCinema3d(Canvas canvas, double w, double h) {
    final centerY = h * 0.48;
    final frameWidth = w * 0.17;
    final frameHeight = h * 0.14;

    // Bingkai Lensa Kiri (Cyan/Biru 3D)
    final leftRect = Rect.fromCenter(
      center: Offset(w * 0.48, centerY),
      width: frameWidth,
      height: frameHeight,
    );
    // Bingkai Lensa Kanan (Merah 3D)
    final rightRect = Rect.fromCenter(
      center: Offset(w * 0.66, centerY),
      width: frameWidth,
      height: frameHeight,
    );

    // Bingkai Hitam Kacamata
    final frameBorderPaint = Paint()
      ..color = const Color(0xFF101010)
      ..style = PaintingStyle.fill;

    // Gagang Kacamata
    final bridgePaint = Paint()
      ..color = const Color(0xFF101010)
      ..strokeWidth = w * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.42, centerY - (h * 0.02)), Offset(w * 0.72, centerY - (h * 0.02)), bridgePaint);

    // Gambar Lensa Kiri (Cyan)
    final cyanPaint = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect.inflate(w * 0.015), Radius.circular(w * 0.03)), frameBorderPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, Radius.circular(w * 0.02)), cyanPaint);

    // Gambar Lensa Kanan (Merah)
    final redPaint = Paint()..color = const Color(0xFFFF1744);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect.inflate(w * 0.015), Radius.circular(w * 0.03)), frameBorderPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, Radius.circular(w * 0.02)), redPaint);

    // Senyum imut di bawah kacamata
    final smilePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(w * 0.49, h * 0.63);
    smilePath.quadraticBezierTo(w * 0.58, h * 0.71, w * 0.66, h * 0.62);
    canvas.drawPath(smilePath, smilePaint);
  }

  // 2. Karakter Pisang Keren (Kacamata Hitam & Bintang)
  void _drawCool(Canvas canvas, double w, double h) {
    final centerY = h * 0.46;

    // Kacamata Hitam Gaul
    final glassesPath = Path();
    glassesPath.moveTo(w * 0.42, centerY - (h * 0.05));
    glassesPath.lineTo(w * 0.74, centerY - (h * 0.05));
    glassesPath.lineTo(w * 0.72, centerY + (h * 0.06));
    glassesPath.lineTo(w * 0.58, centerY + (h * 0.07));
    glassesPath.lineTo(w * 0.56, centerY);
    glassesPath.lineTo(w * 0.44, centerY + (h * 0.05));
    glassesPath.close();

    final glassesPaint = Paint()..color = const Color(0xFF111115);
    canvas.drawPath(glassesPath, glassesPaint);

    // Kilau Putih pada Kacamata
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.46, centerY - (h * 0.02)), Offset(w * 0.51, centerY + (h * 0.03)), shinePaint);
    canvas.drawLine(Offset(w * 0.61, centerY - (h * 0.02)), Offset(w * 0.67, centerY + (h * 0.03)), shinePaint);

    // Kilau Bintang Hijau di Dekat Kacamata
    final starPaint = Paint()..color = const Color(0xFF00E676);
    canvas.drawCircle(Offset(w * 0.42, centerY - (h * 0.03)), w * 0.03, starPaint);

    // Senyum Percaya Diri (Smirk)
    final smirkPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.52, h * 0.64), Offset(w * 0.66, h * 0.59), smirkPaint);
  }

  // 3. Karakter Pisang Mata Kartun Besar (Googly Eyes)
  void _drawGoogly(Canvas canvas, double w, double h) {
    final centerY = h * 0.45;

    // Mata Kiri (Putih Besar)
    final eyeRadius = w * 0.09;
    final leftEyeCenter = Offset(w * 0.50, centerY);
    final rightEyeCenter = Offset(w * 0.65, centerY - (h * 0.02));

    final whiteEyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1A1A1A);
    final reflectionPaint = Paint()..color = Colors.white;

    // Gambar Mata Putih dengan Border Halus
    final eyeBorderPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;

    canvas.drawCircle(leftEyeCenter, eyeRadius, whiteEyePaint);
    canvas.drawCircle(leftEyeCenter, eyeRadius, eyeBorderPaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, whiteEyePaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, eyeBorderPaint);

    // Pupil Hitam Melirik ke Kanan Atas
    final pupilRadius = eyeRadius * 0.5;
    final leftPupil = Offset(leftEyeCenter.dx + (w * 0.025), leftEyeCenter.dy - (h * 0.015));
    final rightPupil = Offset(rightEyeCenter.dx + (w * 0.025), rightEyeCenter.dy - (h * 0.015));

    canvas.drawCircle(leftPupil, pupilRadius, pupilPaint);
    canvas.drawCircle(rightPupil, pupilRadius, pupilPaint);

    // Titik Kilau Refleksi
    canvas.drawCircle(Offset(leftPupil.dx + 2, leftPupil.dy - 2), pupilRadius * 0.35, reflectionPaint);
    canvas.drawCircle(Offset(rightPupil.dx + 2, rightPupil.dy - 2), pupilRadius * 0.35, reflectionPaint);

    // Senyum Imut
    final smilePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(w * 0.50, h * 0.63);
    smilePath.quadraticBezierTo(w * 0.58, h * 0.70, w * 0.66, h * 0.62);
    canvas.drawPath(smilePath, smilePaint);
  }

  // 4. Karakter Pisang Rotten (Busuk dengan Bintik Merah Khas)
  void _drawRotten(Canvas canvas, double w, double h) {
    // Bintik Merah Khas Busuk (seperti pada screenshot!)
    final redSpotPaint = Paint()..color = const Color(0xFFFF5252);
    canvas.drawCircle(Offset(w * 0.65, h * 0.52), w * 0.065, redSpotPaint);

    final innerRedPaint = Paint()..color = const Color(0xFFFF8A80);
    canvas.drawCircle(Offset(w * 0.65, h * 0.52), w * 0.03, innerRedPaint);

    // Bintik-bintik Pembusukan Gelap
    final spotPaint = Paint()..color = const Color(0xFF261812);
    canvas.drawCircle(Offset(w * 0.52, h * 0.38), w * 0.04, spotPaint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.36), w * 0.035, spotPaint);
    canvas.drawCircle(Offset(w * 0.48, h * 0.68), w * 0.045, spotPaint);

    // Mata Ngantuk / Teler (Garis Lengkung Miring)
    final eyePaint = Paint()
      ..color = const Color(0xFF261812)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.46, h * 0.43), Offset(w * 0.54, h * 0.45), eyePaint);

    // Mulut Miring Lucu
    final mouthPaint = Paint()
      ..color = const Color(0xFF261812)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path();
    mouthPath.moveTo(w * 0.50, h * 0.62);
    mouthPath.quadraticBezierTo(w * 0.56, h * 0.66, w * 0.62, h * 0.63);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  // 5. Karakter Pisang Koki (Topi Chef Putih)
  void _drawChef(Canvas canvas, double w, double h) {
    // Topi Koki Putih di atas kepala pisang
    final hatPath = Path();
    final hatBaseY = h * 0.22;
    hatPath.moveTo(w * 0.38, hatBaseY);
    hatPath.lineTo(w * 0.64, hatBaseY - (h * 0.03));
    // Gelembung topi koki (puffs)
    hatPath.cubicTo(w * 0.72, hatBaseY - (h * 0.12), w * 0.64, hatBaseY - (h * 0.22), w * 0.52, hatBaseY - (h * 0.16));
    hatPath.cubicTo(w * 0.46, hatBaseY - (h * 0.24), w * 0.34, hatBaseY - (h * 0.18), w * 0.32, hatBaseY - (h * 0.08));
    hatPath.close();

    final hatPaint = Paint()..color = Colors.white;
    canvas.drawPath(hatPath, hatPaint);

    // Pita Merah di Dasar Topi
    final bandPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.39, hatBaseY + 1), Offset(w * 0.63, hatBaseY - (h * 0.02)), bandPaint);

    // Mata Tersenyum (^ ^)
    final eyePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    final leftEye = Path();
    leftEye.moveTo(w * 0.48, h * 0.43);
    leftEye.quadraticBezierTo(w * 0.52, h * 0.40, w * 0.56, h * 0.43);
    canvas.drawPath(leftEye, eyePaint);

    final rightEye = Path();
    rightEye.moveTo(w * 0.60, h * 0.41);
    rightEye.quadraticBezierTo(w * 0.64, h * 0.38, w * 0.68, h * 0.41);
    canvas.drawPath(rightEye, eyePaint);

    // Senyum Ceria
    final smilePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(w * 0.50, h * 0.58);
    smilePath.quadraticBezierTo(w * 0.58, h * 0.66, w * 0.66, h * 0.58);
    canvas.drawPath(smilePath, smilePaint);
  }

  // 6. Karakter Pisang Klasik Ceria
  void _drawClassic(Canvas canvas, double w, double h) {
    // Mata Kartun Ramah
    final eyeCenter = Offset(w * 0.58, h * 0.42);
    final eyePaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawCircle(eyeCenter, w * 0.045, eyePaint);

    // Kilau Mata
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(eyeCenter.dx + 1.5, eyeCenter.dy - 1.5), w * 0.015, shinePaint);

    // Pipi Merah Merona (Blush)
    final blushPaint = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(w * 0.52, h * 0.52), w * 0.04, blushPaint);

    // Senyum Manis
    final smilePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(w * 0.52, h * 0.58);
    smilePath.quadraticBezierTo(w * 0.60, h * 0.66, w * 0.68, h * 0.57);
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant BananaPainter oldDelegate) {
    return oldDelegate.character != character;
  }
}
