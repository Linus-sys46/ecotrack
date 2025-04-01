// Global theme settings and color palette

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4CAF50); // Eco Green
  static const Color secondaryColor = Color(0xFF388E3C); // Dark Green
  static const Color backgroundColor = Color(0xFFE8F5E9); // Light Green
  static const Color accentColor = Color(0xFF81C784); // Soft Green Accent
  static const Color errorColor = Color(0xFFB71C1C); // Red for Errors

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: secondaryColor,
      error: errorColor,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black), // Heading
      titleLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black), // Subheading
      bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.black87), // Body text
      bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black54), // Smaller body text
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.4),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: primaryColor),
      ),
      labelStyle: GoogleFonts.poppins(color: secondaryColor),
      errorStyle: GoogleFonts.poppins(color: errorColor),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 4,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      elevation: 6,
    ),
  );
}
