import 'package:flutter/material.dart';
import '../../config/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 0),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;

      if (!mounted) return false; // Ensure the widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Press back again to exit"),
          duration: Duration(seconds: 1),
        ),
      );
      return false; // Prevents exiting immediately
    }

    return true; // Exits the app on second back press
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Handles back press behavior
      child: Scaffold(
        backgroundColor:
            AppTheme.backgroundColor, 
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2), 
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor, 
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 60,
                    semanticLabel: 'Eco-friendly logo',
                  ),
                ),
              ),

              const SizedBox(height: 30),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Carbon Tracker",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme
                        .secondaryColor, 
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Track your carbon footprint and reduce your impact!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF388E3C), 
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 100), 
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/signup', (route) => false),
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
                    "Get Started",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
