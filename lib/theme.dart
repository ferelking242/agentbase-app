import 'package:flutter/material.dart';

  const kBg       = Color(0xFF0E0E16);
  const kSidebar  = Color(0xFF0A0A12);
  const kSurface  = Color(0xFF14141E);
  const kSurface2 = Color(0xFF1A1A26);
  const kSurface3 = Color(0xFF20202E);
  const kBorder   = Color(0xFF1C1C2A);
  const kBorder2  = Color(0xFF262636);
  const kText     = Color(0xFFE2E2EE);
  const kText2    = Color(0xFFAEAEC8);
  const kMuted    = Color(0xFF60607A);
  const kMuted2   = Color(0xFF8888A8);
  const kAccent   = Color(0xFF6366F1);
  const kAccentL  = Color(0xFF818CF8);
  const kGreen    = Color(0xFF22C55E);
  const kYellow   = Color(0xFFF59E0B);
  const kRed      = Color(0xFFEF4444);
  const kBlue     = Color(0xFF3B82F6);

  ThemeData buildTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      surface: kBg,
      primary: kAccent,
      secondary: kAccentL,
      error: kRed,
      onSurface: kText,
      outline: kBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: kText,
      titleTextStyle: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: kMuted2, size: 18),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, thickness: 0.5),
    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kText2, fontSize: 14, height: 1.6),
      bodyMedium:  TextStyle(color: kText2, fontSize: 13, height: 1.5),
      bodySmall:   TextStyle(color: kMuted2, fontSize: 11.5),
      titleLarge:  TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleMedium: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleSmall:  TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );