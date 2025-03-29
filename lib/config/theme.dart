// global theme settings and color palette

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4CAF50); // Green
  static const Color secondaryColor = Color(0xFF388E3C); // Dark Green
  static const Color backgroundColor = Color(0xFFE8F5E9); // Light Green
  static const Color errorColor = Color(0xFFB71C1C); // Red

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: secondaryColor,
      error: errorColor,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black54),
    ),
  );
}
