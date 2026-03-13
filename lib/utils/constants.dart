// app-wide constants like API keys and URLs

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constants and configuration loaded from environment.
class AppConstants {
  static String get apiKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get baseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  static const String appName = 'EcoTrack';
}
