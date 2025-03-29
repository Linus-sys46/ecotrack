import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String? emailError;

  void _validateEmail() {
    setState(() {
      emailError = emailController.text.trim().isEmpty
          ? 'Please fill out this field'
          : null;
    });
  }

  void _sendResetLink() async {
    setState(() {
      _validateEmail();
    });

    if (emailError != null) {
      return;
    }

    setState(() => isLoading = true);

    // Simulate sending reset link
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset link sent!"),
          backgroundColor: AppTheme.primaryColor, // Use primaryColor
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Use backgroundColor
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: AppTheme.primaryColor, // Use primaryColor
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Enter your email to receive a password reset link.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.secondaryColor, // Use secondaryColor
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: emailError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor), // Use primaryColor
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _validateEmail(),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor, // Use primaryColor
                    ),
                  )
                : ElevatedButton(
                    onPressed: _sendResetLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.primaryColor, // Use primaryColor
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Send Reset Link",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
