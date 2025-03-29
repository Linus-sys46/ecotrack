import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/forgot_password.dart';
import 'config/theme.dart';

class AppRoutes {
  static const String welcome = '/';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String forgotPassword = '/forgot-password';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text(
                "Page not found",
                style: TextStyle(
                  color: AppTheme.errorColor, // Use errorColor
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
    }
  }
}
