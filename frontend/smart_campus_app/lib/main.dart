import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'auth_screens.dart';

void main() => runApp(const SmartCampusApp());

class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GNITS Smart Campus',
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
