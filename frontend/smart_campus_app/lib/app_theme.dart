import 'package:flutter/material.dart';

// Visual system closely matching the Google AI Studio classroom-management UI:
// white workspace, slate typography, blue institutional accents, compact cards.
const navy = Color(0xFF0B1533);
const navy2 = Color(0xFF172554);
const purple = Color(0xFF4F46E5);
const academicBlue = Color(0xFF06B6D4);
const canvas = Color(0xFFF5F7FC);
const border = Color(0xFFDCE4F0);
const muted = Color(0xFF64748B);
const surface = Color(0xFFFFFFFF);
const surface2 = Color(0xFFF0F4FA);
const neonGreen = Color(0xFF10B981);
const coral = Color(0xFFF43F5E);
const amber = Color(0xFFD97706);

const classroomImage =
    'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&w=1200&q=80';
const hallImage =
    'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?auto=format&fit=crop&w=1200&q=80';
const campusImage =
    'https://images.unsplash.com/photo-1564981797816-1043664bf78d?auto=format&fit=crop&w=1800&q=85';

ThemeData buildAppTheme() {
  const radius = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: canvas,
    colorScheme: const ColorScheme.light(
      primary: purple,
      secondary: academicBlue,
      surface: surface,
      error: coral,
      onPrimary: Colors.white,
      onSurface: navy,
    ),
    fontFamily: 'Arial',
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: navy,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: purple, width: 1.5)),
      labelStyle: TextStyle(color: muted, fontSize: 12),
      prefixIconColor: muted,
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    ),
  );
}
