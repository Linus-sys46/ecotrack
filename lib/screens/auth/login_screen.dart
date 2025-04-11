import 'package:ecotrack/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ecotrack/services/auth_service.dart';
import '../../config/theme.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isForgotPasswordLoading = false;
  bool isPasswordVisible = false;

String? emailError;
  String? passwordError;

final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

void _validateEmail() {
    setState(() {
      final email = emailController.text.trim();
      if (email.isEmpty) {
        emailError = 'Please fill out this field';
      } else if (!_emailRegex.hasMatch(email)) {
        emailError = 'Please enter a valid email address';
      } else {
        emailError = null;
      }
    });
  }

void _validatePassword() {
    setState(() {
      passwordError = passwordController.text.trim().isEmpty
          ? 'Please fill out this field'
          : null;
    });
  }

void _login() async {
    setState(() {
      _validateEmail();
      _validatePassword();
    });

    if (emailError != null || passwordError != null) {
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ));
      } else {
        _showErrorMessage("Invalid login credentials");
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage("Invalid login credentials");
      }
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

void _forgotPassword() async {
    setState(() => isForgotPasswordLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    Navigator.pushNamed(context, '/forgot-password');

    if (mounted) {
      setState(() => isForgotPasswordLoading = false);
    }
  }

void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).padding.top,
            color: AppTheme.primaryColor,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          height: 100,
                          width: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor,
                          ),
                          child: const Icon(Icons.eco,
                              color: Colors.white, size: 50),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          "Login",
                          textAlign: TextAlign.center,
                          style: AppTheme.lightTheme.textTheme.displayLarge
                              ?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: emailError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: AppTheme.primaryColor),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (emailError != null) _validateEmail();
                      },
                      onEditingComplete: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: passwordError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: AppTheme.primaryColor),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !isPasswordVisible,
                      onChanged: (_) => _validatePassword(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: isForgotPasswordLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _forgotPassword,
                              child: Text(
                                "Forgot Password?",
                                style: AppTheme.lightTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style:
                            AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: "Sign Up",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, '/signup');
                              },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
