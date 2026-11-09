import 'package:flutter/material.dart';

import '../core/services/session_service.dart';
import '../features/admin_system/presentation/pages/user_management_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/exam_execution/presentation/pages/exam_list_page.dart';
import '../features/exam_execution/presentation/pages/student_home_page.dart';
import '../features/subject_access/presentation/pages/head_of_subject_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  Widget _getInitialHome() {
    final session = SessionService();
    if (!session.isAuthenticated || session.currentUser == null) {
      return const WelcomePage();
    }

    final role = session.currentUser!.role;
    if (role == 'ADMIN') {
      return const UserManagementPage();
    } else if (role == 'HEAD_OF_SUBJECT') {
      return const HeadOfSubjectPage();
    } else if (role == 'STUDENT') {
      return const StudentHomePage();
    } else {
      return const ExamListPage();
    }
  }

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
      home: _getInitialHome(),
    );
  }
}
