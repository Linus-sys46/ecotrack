import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

class LogActivityCard extends StatefulWidget {
  const LogActivityCard({super.key});

  @override
  State<LogActivityCard> createState() => _LogActivityCardState();
}

class _LogActivityCardState extends State<LogActivityCard> {
  final supabase = Supabase.instance.client;
  String? selectedCategory;
  final TextEditingController detailsController = TextEditingController();
  bool isLoading = false;
  String? resultMessage;

  Future<void> _submitActivity() async {
    if (selectedCategory == null || detailsController.text.trim().isEmpty) {
      setState(() {
        resultMessage = "Please fill out all fields.";
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      // Get the authenticated user's ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          resultMessage = "User not authenticated.";
        });
        setState(() => isLoading = false);
        return;
      }

      // Prepare the data to send to Supabase
      final activityData = {
        'type': selectedCategory, // Use 'type' for category
        'details': detailsController.text.trim(), // Use 'details' for extra info
        'user_id': userId, // Include the authenticated user's ID
      };

      // Insert the data into the 'activities' table
      await supabase.from('activities').insert(activityData);

      setState(() {
        resultMessage = "Activity logged successfully!";
      });
    } catch (error) {
      setState(() {
        resultMessage = "Failed to log activity: $error";
      });
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Log New Activity",
              style: AppTheme.lightTheme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: const [
                DropdownMenuItem(value: "Transport", child: Text("Transport")), // Valid value
                DropdownMenuItem(value: "Energy", child: Text("Energy")),       // Valid value
                DropdownMenuItem(value: "Food", child: Text("Food")),           // Valid value
              ],
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Details Input
            TextField(
              controller: detailsController,
              decoration: InputDecoration(
                labelText: "Details",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Submit Button
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  )
                : ElevatedButton(
                    onPressed: _submitActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Submit Activity",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 16),

            // Result Message
            if (resultMessage != null)
              Text(
                resultMessage!,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
