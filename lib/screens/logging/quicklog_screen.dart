import 'package:flutter/material.dart';
import '../../config/theme.dart';

class QuickLogScreen extends StatelessWidget {
  const QuickLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "This is the Quick Log Page",
          style: AppTheme.lightTheme.textTheme.titleLarge,
        ),
      ),
    );
  }
}
