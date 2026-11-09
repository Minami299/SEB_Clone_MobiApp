import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/welcome_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEB Clone Mobile App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF173A5E),
          primary: const Color(0xFF173A5E),
          surface: const Color(0xFFF3F4F6),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF173A5E), width: 2),
          ),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}
