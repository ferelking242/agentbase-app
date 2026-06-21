import 'package:flutter/material.dart';

const Color kBg = Color(0xFF08080B);
const Color kBg2 = Color(0xFF0D0D11);
const Color kSurface = Color(0xFF13131A);
const Color kSurface2 = Color(0xFF18181F);
const Color kSurface3 = Color(0xFF1F1F28);
const Color kText = Color(0xFFF1F1F3);
const Color kText2 = Color(0xFFC8C8D0);
const Color kMuted = Color(0xFF68687A);
const Color kMuted2 = Color(0xFF9898AA);
const Color kAccent = Color(0xFF6366F1);
const Color kAccent2 = Color(0xFF818CF8);
const Color kGreen = Color(0xFF22C55E);
const Color kRed = Color(0xFFEF4444);
const Color kYellow = Color(0xFFF59E0B);
const Color kPurple = Color(0xFF8B5CF6);
const Color kBorder = Color(0xFF1E1E27);
const Color kBorder2 = Color(0xFF2A2A38);

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      secondary: kAccent2,
      surface: kSurface,
      error: kRed,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg2,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: const CardTheme(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
    ),
    dividerColor: kBorder,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: kText,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: kText,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: kText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: kText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(color: kText2, fontSize: 14, height: 1.6),
      bodyMedium: TextStyle(color: kMuted2, fontSize: 12.5, height: 1.5),
      bodySmall: TextStyle(color: kMuted, fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccent),
      ),
      labelStyle: const TextStyle(color: kMuted2),
      hintStyle: const TextStyle(color: kMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    iconTheme: const IconThemeData(color: kMuted2),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
