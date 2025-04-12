import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? userProfile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            userProfile = null;
            isLoading = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          userProfile = response;
          isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          userProfile = null;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Profile"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProfile == null
              ? const Center(
                  child: Text(
                    "Unable to load profile information.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    AppTheme.primaryColor.withAlpha(50),
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userProfile?['full_name'] ?? "User",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userProfile?['email'] ??
                                        "No email provided",
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Settings Section
                      Text(
                        "Settings",
                        style: AppTheme.lightTheme.textTheme.titleLarge
                            ?.copyWith(color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock,
                                  color: AppTheme.primaryColor),
                              title: const Text("Change Password"),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Handle change password action
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.notifications,
                                  color: AppTheme.primaryColor),
                              title: const Text("Notification Preferences"),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Handle notification preferences action
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.language,
                                  color: AppTheme.primaryColor),
                              title: const Text("Language"),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Handle language selection action
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Support Section
                      Text(
                        "Support",
                        style: AppTheme.lightTheme.textTheme.titleLarge
                            ?.copyWith(color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.help_outline,
                                  color: AppTheme.primaryColor),
                              title: const Text("Help Center"),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Handle help center action
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.feedback_outlined,
                                  color: AppTheme.primaryColor),
                              title: const Text("Send Feedback"),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Handle send feedback action
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Logout Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final shouldLogout = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Confirm Log Out"),
                                content: const Text(
                                    "Are you sure you want to log out?"),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor,
                                      // backgroundColor: AppTheme.errorColor,
                                    ),
                                    child: const Text("Log out"),
                                  ),
                                ],
                              ),
                            );

                            if (shouldLogout == true) {
                              await supabase.auth.signOut();
                              if (mounted) {
                                Navigator.of(context)
                                    .pushReplacementNamed('/login');
                              }
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text("Log Out"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
