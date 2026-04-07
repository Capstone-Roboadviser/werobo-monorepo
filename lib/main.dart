import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'screens/onboarding/splash_screen.dart';

void main() {
  runApp(const WeRoboApp());
}

class WeRoboApp extends StatelessWidget {
  const WeRoboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeRobo',
      debugShowCheckedModeBanner: false,
      theme: WeRoboTheme.light,
      home: const SplashScreen(),
    );
  }
}
