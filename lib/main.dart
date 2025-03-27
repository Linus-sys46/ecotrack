// lib/main.dart
import 'package:ecotrack/screens/auth/forgot_password.dart';
import 'package:ecotrack/screens/welcome/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecotrack/screens/auth/login_screen.dart';
import 'package:ecotrack/screens/auth/signup_screen.dart';
import 'package:ecotrack/screens/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nwjzdtjokxjqgcfipwov.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53anpkdGpva3hqcWdjZmlwd292Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4NDM3MDcsImV4cCI6MjA1NzQxOTcwN30.lXGIij8wBCWUWkqt4mXyiip4-r55Ddf4jsYyeC1VN6I', 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoTrack',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
