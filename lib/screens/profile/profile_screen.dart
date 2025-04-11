import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import 'package:logging/logging.dart';

final _log = Logger('ProfileScreen');

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

  String? footprintScore;
  int? actionsTracked;

  @override
  void initState() {
    super.initState();
    _log.info('Profile screen initialized');
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
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        footprintScore = "Improving";
        actionsTracked = 2;
      });
      _log.info('Carbon footprint data fetched successfully.');
    } catch (error) {
      _log.severe('Error fetching carbon data:', error);
    }
  }

  String formatMemberSince(String? timestamp) {
    if (timestamp == null) return "";
    try {
      DateTime createdAt = DateTime.parse(timestamp);
      return DateFormat("MMMM yyyy").format(createdAt);
    } catch (e) {
      _log.warning('Error parsing timestamp for join date:', e);
      return "";
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : errorMessage != null
              ? Center(
                  child: Text(errorMessage!,
                      style: TextStyle(color: AppTheme.errorColor)))
              : CustomScrollView(
                  slivers: [
                    // App Bar and Cover Image
                    SliverAppBar(
                      automaticallyImplyLeading: false,
                      expandedHeight: 200,
                      pinned: true,
                      backgroundColor: AppTheme.primaryColor,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withAlpha(179),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.cardBackground,
                                    width: 4.0,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppTheme.primaryColor,
                                  child: Text(
                                    getInitials(userData?['full_name']),
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Main Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Info
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData?['full_name'] ?? "Unknown User",
                                    style: AppTheme
                                        .lightTheme.textTheme.displayLarge
                                        ?.copyWith(
                                      fontSize: 24,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Joined ${formatMemberSince(userData?['created_at'])}",
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Your Impact Section
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Your Impact",
                                      style: AppTheme
                                          .lightTheme.textTheme.titleLarge
                                          ?.copyWith(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.bar_chart,
                                            color: AppTheme.primaryColor,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Carbon Footprint Score: ${footprintScore ?? 'N/A'}",
                                            style: AppTheme
                                                .lightTheme.textTheme.bodyLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            color: AppTheme.accentColor,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Sustainable Actions Tracked: ${actionsTracked ?? 'N/A'}",
                                            style: AppTheme
                                                .lightTheme.textTheme.bodyLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Account Information Section
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Account Information",
                                      style: AppTheme
                                          .lightTheme.textTheme.titleLarge
                                          ?.copyWith(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.email,
                                            color: AppTheme.accentColor,
                                            size: 20),
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
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Logout Button
                            Center(
                              child: GestureDetector(
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
                                                  AppTheme.errorColor,
                                            ),
                                            child: const Text("Logout"),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await supabase.auth.signOut();
                                              if (context.mounted) {
                                                Navigator.pushReplacementNamed(
                                                    context, '/login');
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withAlpha(26),
                                    border:
                                        Border.all(color: AppTheme.errorColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.logout,
                                          color: AppTheme.errorColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Logout",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyLarge
                                            ?.copyWith(
                                          color: AppTheme.errorColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Footer
                            Center(
                              child: Text(
                                "Powered by Ecotrack",
                                style: AppTheme.lightTheme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
