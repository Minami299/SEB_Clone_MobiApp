import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService().init();
  runApp(const App());
}
