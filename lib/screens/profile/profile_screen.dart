import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import 'package:logging/logging.dart'; // Import the logging framework

final _log = Logger('ProfileScreen'); // Create a logger instance

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  // Variables to hold fetched carbon footprint data
  String? footprintScore;
  int? actionsTracked;

  @override
  void initState() {
    super.initState();
    _log.info('Profile screen initialized'); // Example of using the logger
    fetchUserProfileAndCarbonData();
  }

  Future<void> fetchUserProfileAndCarbonData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = "No user is logged in.";
          isLoading = false;
        });
        _log.warning('No user is logged in.');
        return;
      }

      // Fetch user profile data
      final profileResponse = await supabase
          .from('profiles')
          .select('full_name, email, created_at')
          .eq('id', user.id)
          .single();

      setState(() {
        userData = profileResponse;
      });
      _log.info(
          'User profile fetched successfully: ${profileResponse['full_name']}');

      // Fetch carbon footprint data using your APIs
      await fetchCarbonFootprintData(user.id);

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = "Failed to fetch profile or carbon data: $error";
        isLoading = false;
      });
      _log.severe('Failed to fetch profile or carbon data:', error);
    }
  }

  Future<void> fetchCarbonFootprintData(String userId) async {
    try {
      // Simulate API calls (replace with your actual API calls)
      // You might need to send the userId or other relevant data to your APIs

      // Example API call for footprint score
      // final scoreResponse = await YourCarbonApi.getFootprintScore(userId);
      // if (scoreResponse.success) {
      //   footprintScore = scoreResponse.data['score'];
      // }

      // Example API call for actions tracked
      // final actionsResponse = await YourCarbonApi.getActionsTracked(userId);
      // if (actionsResponse.success) {
      //   actionsTracked = actionsResponse.data['count'];
      // }

      // For demonstration purposes with simulated data:
      await Future.delayed(const Duration(seconds: 1)); // Simulate API delay
      setState(() {
        footprintScore = "Improving";
        actionsTracked = 2;
      });
      _log.info('Carbon footprint data fetched successfully.');
    } catch (error) {
      _log.severe('Error fetching carbon data:', error);
      // Optionally set error messages for specific carbon data fields
    }
  }

  String formatMemberSince(String? timestamp) {
    if (timestamp == null) return "";
    try {
      DateTime createdAt = DateTime.parse(timestamp);
      return DateFormat("MMMM yyyy")
          .format(createdAt); // Correct format for "Month Year"
    } catch (e) {
      _log.warning('Error parsing timestamp for join date:', e);
      return ""; // Return an empty string or a default value on error
    }
  }

  String getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return "U";
    }
    final names = fullName.split(" ");
    final initials = names.map((name) => name.isNotEmpty ? name[0] : "").join();
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Your Profile"),
        backgroundColor: AppTheme.primaryColor,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : errorMessage != null
              ? Center(
                  child: Text(errorMessage!,
                      style: TextStyle(color: AppTheme.errorColor)))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 3.0,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: AppTheme.primaryColor
                                .withAlpha(204), // Fixed: Replaced withAlpha
                            child: Text(
                              getInitials(userData?['full_name']),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          userData?['full_name'] ?? "Unknown User",
                          style: AppTheme.lightTheme.textTheme.headlineMedium
                                  ?.copyWith(
                                      color: AppTheme.secondaryColor,
                                      fontWeight: FontWeight.w700) ??
                              const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Joined on ${formatMemberSince(userData?['created_at'])}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(100),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Impact",
                                style: AppTheme.lightTheme.textTheme.titleLarge
                                        ?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600) ??
                                    const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart,
                                      color: AppTheme.primaryColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Carbon Footprint Score: ${footprintScore ?? 'N/A'}",
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Sustainable Actions Tracked: ${actionsTracked ?? 'N/A'}",
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                  height: 30,
                                  thickness: 0.8,
                                  color: Colors.grey),
                              Text(
                                "Account Information",
                                style: AppTheme.lightTheme.textTheme.titleLarge
                                        ?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600) ??
                                    const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Icon(Icons.email,
                                      color: AppTheme.accentColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      userData?['email'] ?? "N/A",
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                  height: 30,
                                  thickness: 0.8,
                                  color: Colors.grey),
                              SizedBox(
                                width: double.infinity,
                                child: InkWell(
                                  onTap: () async {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text("Confirm Logout"),
                                          content: const Text(
                                              "Are you sure you want to logout?"),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text("Cancel"),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.redAccent),
                                              child: const Text("Logout"),
                                              onPressed: () async {
                                                Navigator.of(context)
                                                    .pop(); // Close the dialog
                                                await supabase.auth.signOut();
                                                if (context.mounted) {
                                                  Navigator
                                                      .pushReplacementNamed(
                                                          context, '/login');
                                                }
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.logout,
                                            color: Colors.redAccent),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Logout',
                                          style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          "Powered by Ecotrack",
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
