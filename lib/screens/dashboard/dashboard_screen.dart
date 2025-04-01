import 'package:ecotrack/screens/dashboard/dashboard_content.dart';
import 'package:ecotrack/screens/insights/insights_screen.dart';
import 'package:ecotrack/screens/logging/activities_screen.dart';
import 'package:ecotrack/screens/logging/log_activity_card.dart';
import 'package:ecotrack/screens/logging/quicklog_screen.dart';
import 'package:ecotrack/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardContent(), // Dashboard
    const ActivitiesScreen(), // Activities
    const QuickLogScreen(), // Quick Log
    const InsightsScreen(), // Insights
    const ProfileScreen(), // Profile
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        builder: (context) => const LogActivityCard(), // Open LogActivityCard
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDashboard = _selectedIndex == 0;

    return Scaffold(
      appBar: isDashboard
          ? AppBar(
              automaticallyImplyLeading: false, // Removes the back button
              title: const Text("Dashboard"),
              backgroundColor: AppTheme.primaryColor,
            )
          : null, // No AppBar for other screens

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages, // Preloaded pages
      ),

      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: "Dashboard"),
            BottomNavigationBarItem(
                icon: Icon(Icons.list), label: "Activities"),
            BottomNavigationBarItem(icon: Icon(null), label: ""), // Quick Log
            BottomNavigationBarItem(
                icon: Icon(Icons.insights), label: "Insights"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2), // Opens the Quick Log modal
        backgroundColor: AppTheme.primaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
