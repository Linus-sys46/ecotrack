import 'package:flutter/material.dart';
import 'package:ecotrack/services/auth_service.dart';
import '../../config/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await AuthService().signOut();
      navigator.pushReplacementNamed('/login');
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable the back button
        title: const Text("Dashboard"),
        backgroundColor: AppTheme.primaryColor, // Use primaryColor
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome to Ecotrack Dashboard!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Here's what you can do:",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.emoji_transportation),
              title: const Text("Track Your Transport Footprint"),
              onTap: () => Navigator.pushNamed(context, '/transportTracking'),
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text("Monitor Your Energy Usage"),
              onTap: () => Navigator.pushNamed(context, '/energyTracking'),
            ),
            ListTile(
              leading: const Icon(Icons.food_bank),
              title: const Text("Log Your Food Consumption"),
              onTap: () => Navigator.pushNamed(context, '/foodTracking'),
            ),
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text("View Insights and Recommendations"),
              onTap: () => Navigator.pushNamed(context, '/insights'),
            ),
          ],
        ),
      ),
    );
  }
}


