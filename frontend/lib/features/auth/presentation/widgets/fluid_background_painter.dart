import 'package:flutter/material.dart';

class FluidBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color darkWaveColor;
  final Color lightWaveColor;

  FluidBackgroundPainter({
    this.primaryColor = const Color(0xFF0062FF),
    this.darkWaveColor = const Color(0xFF004BD6),
    this.lightWaveColor = const Color(0xFF1A75FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Nền Gradient chuyển màu xanh
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [primaryColor, darkWaveColor],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // 2. Lớp sóng chất lỏng đậm (Dark fluid wave)
    paint.color = darkWaveColor.withOpacity(0.55);
    final darkPath = Path();
    darkPath.moveTo(0, size.height * 0.22);
    darkPath.cubicTo(
      size.width * 0.35, size.height * 0.12,
      size.width * 0.65, size.height * 0.42,
      size.width, size.height * 0.32,
    );
    darkPath.lineTo(size.width, size.height * 0.72);
    darkPath.cubicTo(
      size.width * 0.7, size.height * 0.82,
      size.width * 0.25, size.height * 0.58,
      0, size.height * 0.76,
    );
    darkPath.close();
    canvas.drawPath(darkPath, paint);

    // 3. Lớp sóng sáng (Light wave blob)
    paint.color = lightWaveColor.withOpacity(0.3);
    final lightPath = Path();
    lightPath.moveTo(size.width * 0.15, 0);
    lightPath.cubicTo(
      size.width * 0.75, size.height * 0.04,
      size.width * 0.95, size.height * 0.28,
      size.width * 0.58, size.height * 0.42,
    );
    lightPath.cubicTo(
      size.width * 0.25, size.height * 0.55,
      size.width * 0.05, size.height * 0.3,
      size.width * 0.15, 0,
    );
    lightPath.close();
    canvas.drawPath(lightPath, paint);

    // 4. Các bọt khí / giọt nước tròn (Floating Droplets)
    paint.color = const Color(0xFF003CB3).withOpacity(0.65);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.2), size.width * 0.11, paint);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.45), size.width * 0.085, paint);
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.66), size.width * 0.065, paint);

    paint.color = lightWaveColor.withOpacity(0.45);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.16), size.width * 0.045, paint);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.37), size.width * 0.04, paint);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.68), size.width * 0.07, paint);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.18), size.width * 0.035, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
