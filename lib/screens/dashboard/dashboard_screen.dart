import 'package:flutter/material.dart';
import 'package:ecotrack/services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
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


