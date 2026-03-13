import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecotrack/services/auth_service.dart';
import '../../config/theme.dart';

class SignUpScreen extends StatefulWidget {
const SignUpScreen({super.key});

@override
State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
final AuthService _authService = AuthService();
final TextEditingController emailController = TextEditingController();
final TextEditingController passwordController = TextEditingController();
final TextEditingController fullNameController = TextEditingController();
bool isLoading = false;
bool isPasswordVisible = false;

String? fullNameError;
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

void _validateFullName() {
setState(() {
  fullNameError = fullNameController.text.trim().isEmpty
      ? 'Please fill out this field'
      : null;
});
}

void _validatePassword() {
setState(() {
  passwordError = passwordController.text.trim().isEmpty
      ? 'Please fill out this field'
      : null;
});
}

void _signup() async {
setState(() {
  _validateFullName();
  _validateEmail();
  _validatePassword();
});

if (fullNameError != null || emailError != null || passwordError != null) {
  return;
}

setState(() => isLoading = true);

try {
  await _authService.signUp(
    emailController.text.trim(),
    passwordController.text.trim(),
    fullNameController.text.trim(),
  );

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        "Account created. Please check your email to verify before logging in.",
      ),
      backgroundColor: Colors.green,
    ),
  );
} on AuthException catch (e) {
  if (!mounted) return;

  String message = 'Signup failed. Please try again.';

  if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit') {
    message =
        'Too many sign-up emails were requested. Please wait a few minutes and try again.';
  } else if (e.message.isNotEmpty) {
    message = e.message;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
} catch (_) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Signup failed. Please try again later.'),
    ),
  );
}

if (mounted) setState(() => isLoading = false);
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
                // Profile Icon
                Container(
                  height: 100,
                  width: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor,
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 50),
                ),
                const SizedBox(height: 30),
                Text(
                  "Sign Up",
                  textAlign: TextAlign.center,
                  style:
                      AppTheme.lightTheme.textTheme.displayLarge?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    errorText: fullNameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor), 
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _validateFullName(),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: emailError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor), 
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
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor), 
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                        onPressed: _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.primaryColor, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Sign Up",
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
                    text: "Already have an account? ",
                    style: AppTheme.lightTheme.textTheme
                        .bodyLarge, 
                    children: [
                      TextSpan(
                        text: "Login",
                        style: AppTheme.lightTheme.textTheme.titleLarge
                            ?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pushNamed(context, '/login');
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
