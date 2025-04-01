import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

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

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = "No user is logged in.";
          isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('full_name, email,created_at')
          .eq('id', user.id)
          .single();

      setState(() {
        userData = response;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = "Failed to fetch profile: $error";
        isLoading = false;
      });
    }
  }

  String formatMemberSince(String? timestamp) {
    if (timestamp == null) return "";
    DateTime createdAt = DateTime.parse(timestamp);
    return DateFormat("MMMM yyyy").format(createdAt); // Example: "March 2024"
  }

  String getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty)
      return "U"; // Default to "U" for unknown
    final names = fullName.split(" ");
    final initials = names.map((name) => name.isNotEmpty ? name[0] : "").join();
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Removed unused variable 'screenWidth'

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Profile"),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Themed Avatar
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppTheme
                              .primaryColor, // Use primaryColor from theme
                          child: Text(
                            getInitials(userData?['full_name']),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Use white for contrast
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // User Name
                        Text(
                          userData?['full_name'] ?? "Unknown User",
                          style: AppTheme.lightTheme.textTheme.displayLarge
                              ?.copyWith(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Member Since
                        Text(
                          "Member since ${formatMemberSince(userData?['created_at'])}",
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // User Details Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color:
                                Colors.white, // Use white for card background
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.1), // Subtle shadow
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email
                              Row(
                                children: [
                                  const Icon(Icons.email,
                                      color: AppTheme
                                          .primaryColor), // Use primaryColor
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      userData?['email'] ?? "N/A",
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, thickness: 1),
                              const Divider(height: 24, thickness: 1),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Edit Profile Button
                            ElevatedButton.icon(
                              onPressed: () {
                                // Handle edit profile action
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                "Edit Profile",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            // Logout Button
                            ElevatedButton.icon(
                              onPressed: () async {
                                await supabase.auth.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context,
                                      '/login'); // Navigate to login page
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme
                                    .errorColor, // Use errorColor for logout button
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon:
                                  const Icon(Icons.logout, color: Colors.white),
                              label: const Text(
                                "Logout",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
