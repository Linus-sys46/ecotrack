import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import 'log_activity_card.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> activities = [];
  bool isLoading = true;
  bool isExpanded = false; // Tracks whether the list is expanded

  @override
  void initState() {
    super.initState();
    fetchActivities();
  }

  Future<void> fetchActivities() async {
    setState(() => isLoading = true);

    try {
      // Get the authenticated user's ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          activities = [];
          isLoading = false;
        });
        return;
      }

      // Fetch activities for the current user, sorted by creation time in descending order
      final response = await supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId) // Filter by user ID
          .order('created_at', ascending: false); // Sort by time, descending

      setState(() {
        activities = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        activities = [];
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch activities: $error"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String formatRelativeDate(String? timestamp) {
    if (timestamp == null) return "Unknown";
    final DateTime date = DateTime.parse(timestamp)
        .toUtc()
        .toLocal(); // Convert UTC to local time
    final DateTime now = DateTime.now();

    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      return "Today";
    } else if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)))) {
      return "Yesterday";
    } else {
      return DateFormat('MMMM d, yyyy').format(date); // Example: "March 5, 2024"
    }
  }

  IconData getIconForType(String? type) {
    switch (type) {
      case "Transport":
        return Icons.directions_bus; // Icon for transport
      case "Energy":
        return Icons.lightbulb; // Icon for energy
      case "Food":
        return Icons.restaurant; // Icon for food
      default:
        return Icons.help_outline; // Default icon
    }
  }

  void onFabPressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LogActivityCard(),
    ).whenComplete(() {
      fetchActivities(); // Refresh activities after logging a new one
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Your Activities"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activities.isEmpty
              ? const Center(child: Text("No activities logged yet."))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Recent Activity",
                        style:
                            AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: isExpanded
                            ? activities.length + 1 // Add 1 for "See Less" link
                            : (activities.length > 3
                                ? 4
                                : activities
                                    .length), // Show 3 activities + "View All" link
                        itemBuilder: (context, index) {
                          if (!isExpanded && index == 3) {
                            // Show "View All" link as the 4th item
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 8.0), // Align with card padding
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isExpanded = true; // Expand the list
                                  });
                                },
                                child: Text(
                                  "View All",
                                  style: TextStyle(
                                    color: Colors
                                        .blue, // Intuitive color for "View All"
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (isExpanded && index == activities.length) {
                            // Show "See Less" link as the last item
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 8.0), // Align with card padding
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isExpanded = false; // Collapse the list
                                  });
                                },
                                child: Text(
                                  "See Less",
                                  style: TextStyle(
                                    color: Colors
                                        .red, // Intuitive color for "See Less"
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }

                          final activity = activities[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                getIconForType(activity['type']),
                                color: AppTheme.primaryColor,
                              ),
                              title: Text(activity['type'] ?? "Unknown"),
                              subtitle:
                                  Text(activity['details'] ?? "No details"),
                              trailing: Text(
                                formatRelativeDate(activity['created_at']),
                                style: AppTheme.lightTheme.textTheme.bodyMedium,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: onFabPressed,
        backgroundColor: AppTheme.primaryColor,
        shape: const CircleBorder(), // Ensure the button is circular
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
