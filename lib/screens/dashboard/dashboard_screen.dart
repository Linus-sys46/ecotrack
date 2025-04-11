import 'package:ecotrack/screens/dashboard/dashboard_content.dart';
import 'package:ecotrack/screens/inputs/input_screen.dart';
import 'package:ecotrack/screens/insights/insights_screen.dart';
import 'package:ecotrack/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> emissions = [];
  String status = 'Loading...';

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize pages with a callback to update emissions and status
    _pages = [
      DashboardContent(
        onDataFetched: (fetchedEmissions, fetchedStatus) {
          setState(() {
            emissions = fetchedEmissions;
            status = fetchedStatus;
            // Update InsightsScreen with the latest emissions and status
            _pages[2] = InsightsScreen(emissions: emissions, status: status);
          });
        },
      ),
      const InputScreen(),
      InsightsScreen(emissions: emissions, status: status),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Update InsightsScreen with the latest emissions and status when the Insights tab is selected
      if (index == 2) {
        _pages[2] = InsightsScreen(emissions: emissions, status: status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDashboard = _selectedIndex == 0;

    return Scaffold(
      appBar: isDashboard
          ? AppBar(
              automaticallyImplyLeading: false,
              title: const Text("Dashboard"),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 3,
          indicatorColor: AppTheme.primaryColor,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.bar_chart, size: 28),
              selectedIcon: Icon(Icons.bar_chart_outlined, size: 28),
              label: "Dashboard",
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_rounded, size: 28),
              selectedIcon: Icon(Icons.add_circle, size: 28),
              label: "Inputs",
            ),
            NavigationDestination(
              icon: Icon(Icons.lightbulb_circle_outlined, size: 28),
              selectedIcon: Icon(Icons.lightbulb_circle, size: 28),
              label: "Insights",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, size: 28),
              selectedIcon: Icon(Icons.person, size: 28),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
