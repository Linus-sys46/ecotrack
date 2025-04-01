import 'package:flutter/material.dart';
import '../../config/theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Insights & Recommendations"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Personalized Recommendations",
              style: AppTheme.lightTheme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_bus,
                    color: AppTheme.primaryColor),
                title: const Text("Switch to public transport"),
                subtitle: const Text("Save 12kg CO₂ per week."),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.lightbulb, color: AppTheme.secondaryColor),
                title: const Text("Switch to LED bulbs"),
                subtitle: const Text("Reduce energy emissions by 20%."),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
