import 'package:flutter/material.dart';

/// AppTheme defines the high-contrast, professional styling for the Legal Metrology Inspector app.
/// Designed for rapid readability and field-use under various lighting conditions.
class AppTheme {
  AppTheme._();

  // Official Legal Metrology / Government Enforcement Palette
  static const Color primaryNavy = Color(0xFF0C2340);       // Deep Navy
  static const Color primaryBlue = Color(0xFF1B4980);       // Enforcement Blue
  static const Color accentGold = Color(0xFFC8963E);        // Department Emblem Gold
  static const Color surfaceLight = Color(0xFFF1F5F9);      // Neutral slate gray background
  static const Color cardBackground = Colors.white;

  // 2px Solid Semantic Border Tokens
  static const Color passBorder = Color(0xFF16A34A);
  static const Color violationBorder = Color(0xFFDC2626);
  static const Color neutralBorder = Color(0xFFCBD5E1);

  // Compliance Status Colors
  static const Color violationRed = Color(0xFFDC2626);
  static const Color violationBackground = Color(0xFFFFEBEE);
  static const Color violationText = Color(0xFFB71C1C);

  static const Color passGreen = Color(0xFF16A34A);
  static const Color passBackground = Color(0xFFE8F5E9);
  static const Color passText = Color(0xFF15803D);

  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningBackground = Color(0xFFFFFBEB);

  // High-Glare Field Text Hierarchy
  static const Color primaryInk = Color(0xFF0F172A);         // Titles >=18sp (weights 700-800)
  static const Color secondaryText = Color(0xFF334155);      // Body (14sp)
  static const Color metadataLabel = Color(0xFF64748B);      // Labels (11-12sp)

  static const Color textPrimary = primaryInk;
  static const Color textSecondary = secondaryText;
  static const Color borderLight = neutralBorder;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: primaryBlue,
        tertiary: accentGold,
        surface: surfaceLight,
        error: violationRed,
      ),
      scaffoldBackgroundColor: surfaceLight,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: primaryNavy, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: violationRed, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: accentGold.withAlpha(45),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryNavy, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryNavy,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryNavy,
        secondarySelectedColor: primaryNavy,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderLight),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
