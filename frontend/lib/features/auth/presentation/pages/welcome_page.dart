import 'package:flutter/material.dart';
import '../widgets/fluid_background_painter.dart';
import 'login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0062FF),
      body: Stack(
        children: [
          // 1. Nền lượn sóng & bọt khí chất lỏng toàn màn hình
          Positioned.fill(
            child: CustomPaint(
              painter: FluidBackgroundPainter(),
            ),
          ),

          // 2. Nội dung chính
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo góc trên bên trái
                  const Text(
                    'SEB Mobile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const Spacer(),

                  // Tiêu đề thương hiệu
                  const Text(
                    'Safe Exam Browser',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phụ đề mô tả
                  const Text(
                    'Hệ thống thi an toàn, bảo mật cao và giám sát chống gian lận thông minh trên thiết bị di động.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Nút 1: Nền trắng chữ xanh "Đăng nhập" (Chuyển sang màn hình 2)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;
                              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                              return SlideTransition(position: animation.drive(tween), child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 350),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0062FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
