import 'package:flutter/material.dart';

abstract final class VisitColors {
  static const background = Color(0xFFF5F6F8);
  static const ink = Color(0xFF101828);
  static const secondary = Color(0xFF475467);
  static const border = Color(0xFFE4E7EC);
  static const skeletonLight = Color(0xFFEEF0F3);
  static const accent = Color(0xFF0E7C66);
  static const done = Color(0xFF067647);
  static const pending = Color(0xFFB54708);
  static const pendingBackground = Color(0xFFFFF4E5);
  static const error = Color(0xFFB42318);
  static const errorBackground = Color(0xFFFEF3F2);
  static const snackbarAction = Color(0xFF7DD9C3);
}

abstract final class VisitType {
  static const heading = TextStyle(
    letterSpacing: 0,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: VisitColors.ink,
  );
  static const title = TextStyle(
    letterSpacing: 0,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: VisitColors.ink,
  );
  static const timestamp = TextStyle(
    letterSpacing: 0,
    fontSize: 13,
    height: 18 / 13,
    color: VisitColors.secondary,
  );
  static const badge = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: .2,
  );
}

ThemeData visitTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'IBM Plex Sans',
  scaffoldBackgroundColor: VisitColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: VisitColors.accent,
    primary: VisitColors.accent,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: VisitColors.accent,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VisitColors.accent,
      foregroundColor: Colors.white,
      minimumSize: const Size(88, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: VisitColors.ink,
    actionTextColor: VisitColors.snackbarAction,
    contentTextStyle: const TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontSize: 14,
      color: Colors.white,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);
