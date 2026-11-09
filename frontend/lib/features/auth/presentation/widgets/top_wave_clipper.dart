import 'package:flutter/material.dart';

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    // Đường cong mềm mại hình sóng nước theo đúng ảnh mẫu
    path.cubicTo(
      size.width * 0.32, size.height + 25,
      size.width * 0.68, size.height - 65,
      size.width, size.height - 25,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
