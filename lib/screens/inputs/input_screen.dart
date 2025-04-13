import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import 'package:logging/logging.dart';

final _log = Logger('InputScreen');

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  String? _institution;
  final _siteController = TextEditingController();
  String? _primarySource;
  final _primaryAmountController = TextEditingController();
  String? _secondarySource;
  final _secondaryAmountController = TextEditingController();
  String? _replenish;
  final _customReplenishController = TextEditingController();
  final _hoursController = TextEditingController();

  // State variables
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;
  bool hasSubmitted = false;
  Map<String, dynamic>?
      latestEmission; // Store the latest submitted emission data

  // Options for dropdowns
  final List<String> institutions = ['Daystar University', 'USIU'];
  final List<String> energySources = [
    'LPG',
    'Charcoal',
    'Electricity',
    'Diesel',
    'Other'
  ];
  final List<String> replenishOptions = [
    'Per Day',
    'Daily',
    'Weekly',
    'Monthly',
  ];

  // Filter secondary source options based on primary source
  List<String> getAvailableSecondarySources() {
    if (_primarySource == null) {
      return energySources;
    }
    return energySources.where((source) => source != _primarySource).toList();
  }

  @override
  void initState() {
    super.initState();
    // Subscribe to real-time changes in the emissions table
    supabase
        .channel('public:emissions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'emissions',
          callback: (payload) {
            _fetchLatestEmission();
          },
        )
        .subscribe();

    // Fetch initial latest emission data
    _fetchLatestEmission();
  }

  // Fetch the latest emission data from the database
  Future<void> _fetchLatestEmission() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('emissions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          latestEmission = response;
        });
      }
    } catch (error) {
      _log.severe('Error fetching latest emission:', error);
    }
  }

  // Check for duplicate site within institution
  Future<bool> _checkDuplicateSite(String institution, String site) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final response = await supabase
          .from('emissions')
          .select()
          .eq('user_id', userId)
          .eq('institution', institution)
          .eq('site', site);
      return response.isNotEmpty;
    } catch (error) {
      _log.severe('Error checking duplicate site:', error);
      return false;
    }
  }

  // Calculate total emissions (unchanged)
  double calculateTotalEmissions(Map<String, dynamic> emission) {
    final double primaryAmount = (emission['primary_amount'] ?? 0).toDouble();
    final double secondaryAmount =
        (emission['secondary_amount'] ?? 0).toDouble();
    final double hours = (emission['hours'] ?? 0).toDouble();
    const double emissionFactor = 0.5; // Example: 0.5 kg CO2 per unit
    return (primaryAmount + secondaryAmount) * hours * emissionFactor;
  }

  @override
  void dispose() {
    _siteController.dispose();
    _primaryAmountController.dispose();
    _secondaryAmountController.dispose();
    _customReplenishController.dispose();
    _hoursController.dispose();
    supabase.channel('public:emissions').unsubscribe();
    super.dispose();
  }

  Future<void> submitEmissionData() async {
    setState(() {
      hasSubmitted = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check for duplicate site within institution
    final site = _siteController.text.trim();
    if (_institution != null) {
      final isDuplicate = await _checkDuplicateSite(_institution!, site);
      if (isDuplicate) {
        setState(() {
          errorMessage =
              "Site '$site' already exists for $_institution. Please use a different site name or update the existing entry.";
          hasSubmitted = false;
        });
        return;
      }
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = "You must be logged in to submit data.";
          isLoading = false;
        });
        _log.warning('No user logged in during submission.');
        return;
      }

      // Determine the replenish value to submit
      final String replenishValue = _replenish == 'Other'
          ? _customReplenishController.text.trim()
          : _replenish!;

      // Prepare data for submission
      final emissionData = {
        'user_id': user.id,
        'institution': _institution,
        'site': site,
        'primary_source': _primarySource,
        'primary_amount':
            double.parse(_primaryAmountController.text.trim()).toDouble(),
        'secondary_source': _secondarySource,
        'secondary_amount': _secondaryAmountController.text.isNotEmpty
            ? double.parse(_secondaryAmountController.text.trim()).toDouble()
            : null,
        'replenish': replenishValue,
        'hours': double.parse(_hoursController.text.trim()).toDouble(),
      };

      // Submit to Supabase
      final response =
          await supabase.from('emissions').insert(emissionData).select();

      if (response.isNotEmpty) {
        setState(() {
          successMessage = "Emission data submitted successfully!";
          isLoading = false;
          hasSubmitted = false;
        });
        _log.info('Emission data submitted successfully: $emissionData');

        // Clear the form
        _formKey.currentState!.reset();
        _siteController.clear();
        _primaryAmountController.clear();
        _secondaryAmountController.clear();
        _customReplenishController.clear();
        _hoursController.clear();
        setState(() {
          _institution = null;
          _primarySource = null;
          _secondarySource = null;
          _replenish = null;
        });

        // Hide success message after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            successMessage = null;
          });
        }
      }
    } catch (error) {
      setState(() {
        errorMessage = "Failed to submit data: $error";
        isLoading = false;
      });
      _log.severe('Error submitting emission data:', error);
    }
  }

  // Function to clear error messages when the user starts interacting
  void _clearErrorMessage() {
    if (errorMessage != null) {
      setState(() {
        errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get available secondary sources
    final availableSecondarySources = getAvailableSecondarySources();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Log Emission Data"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: CustomScrollView(
        slivers: [
          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Institution
                            Text(
                              "Institution",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _institution,
                              decoration: const InputDecoration(
                                hintText: "Select institution",
                                prefixIcon: Icon(Icons.school,
                                    color: AppTheme.primaryColor),
                              ),
                              items: institutions.map((inst) {
                                return DropdownMenuItem<String>(
                                  value: inst,
                                  child: Text(inst),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _institution = value;
                                  _clearErrorMessage();
                                  if (hasSubmitted) {
                                    _formKey.currentState?.validate();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return "Please select an institution.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Site
                            Text(
                              "Site",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _siteController,
                              decoration: const InputDecoration(
                                hintText: "e.g., Chilton’s Restaurant",
                                prefixIcon: Icon(Icons.location_on,
                                    color: AppTheme.primaryColor),
                              ),
                              onChanged: (value) {
                                _clearErrorMessage();
                                if (hasSubmitted) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter a site.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Primary Source
                            Text(
                              "Primary Energy Source",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _primarySource,
                              decoration: const InputDecoration(
                                hintText: "Select primary source",
                                prefixIcon: Icon(Icons.power,
                                    color: AppTheme.primaryColor),
                              ),
                              items: energySources.map((source) {
                                return DropdownMenuItem<String>(
                                  value: source,
                                  child: Text(source),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _primarySource = value;
                                  if (_secondarySource == value) {
                                    _secondarySource = null;
                                    _secondaryAmountController.clear();
                                  }
                                  _clearErrorMessage();
                                  if (hasSubmitted) {
                                    _formKey.currentState?.validate();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return "Please select a primary energy source.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Primary Amount
                            Text(
                              "Primary Amount (kg or kWh)",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _primaryAmountController,
                              decoration: const InputDecoration(
                                hintText: "e.g., 20",
                                prefixIcon: Icon(Icons.scale,
                                    color: AppTheme.primaryColor),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _clearErrorMessage();
                                if (hasSubmitted) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter the primary amount.";
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return "Please enter a valid positive number.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Secondary Source (Optional)
                            Text(
                              "Secondary Energy Source (Optional)",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _secondarySource,
                              decoration: const InputDecoration(
                                hintText: "Select secondary source",
                                prefixIcon: Icon(Icons.power,
                                    color: AppTheme.accentColor),
                              ),
                              items: availableSecondarySources.map((source) {
                                return DropdownMenuItem<String>(
                                  value: source,
                                  child: Text(source),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _secondarySource = value;
                                  _clearErrorMessage();
                                  if (hasSubmitted) {
                                    _formKey.currentState?.validate();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Secondary Amount (Optional)
                            Text(
                              "Secondary Amount (kg or kWh, Optional)",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _secondaryAmountController,
                              decoration: const InputDecoration(
                                hintText: "e.g., 10",
                                prefixIcon: Icon(Icons.scale,
                                    color: AppTheme.accentColor),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _clearErrorMessage();
                                if (hasSubmitted) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null; // Optional field
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return "Please enter a valid positive number.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Replenish
                            Text(
                              "Replenish Frequency",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _replenish,
                              decoration: const InputDecoration(
                                hintText: "Select frequency",
                                prefixIcon: Icon(Icons.eco,
                                    color: AppTheme.primaryColor),
                              ),
                              items: replenishOptions.map((option) {
                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _replenish = value;
                                  _customReplenishController.clear();
                                  _clearErrorMessage();
                                  if (hasSubmitted) {
                                    _formKey.currentState?.validate();
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return "Please select a frequency.";
                                }
                                return null;
                              },
                            ),
                            if (_replenish == 'Other') ...[
                              const SizedBox(height: 16),
                              Text(
                                "Custom Replenish Frequency",
                                style: AppTheme.lightTheme.textTheme.titleLarge
                                    ?.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _customReplenishController,
                                decoration: const InputDecoration(
                                  hintText: "e.g., Biweekly",
                                  prefixIcon: Icon(Icons.edit,
                                      color: AppTheme.primaryColor),
                                ),
                                onChanged: (value) {
                                  _clearErrorMessage();
                                  if (hasSubmitted) {
                                    _formKey.currentState?.validate();
                                  }
                                },
                                validator: (value) {
                                  if (_replenish == 'Other' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return "Please enter a custom frequency.";
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Hours
                            Text(
                              "Operational Hours",
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _hoursController,
                              decoration: const InputDecoration(
                                hintText: "e.g., 8",
                                prefixIcon: Icon(Icons.timer,
                                    color: AppTheme.primaryColor),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _clearErrorMessage();
                                if (hasSubmitted) {
                                  _formKey.currentState?.validate();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter operational hours.";
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return "Please enter a valid positive number.";
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  Center(
                    child: GestureDetector(
                      onTap: isLoading ? null : submitEmissionData,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 32),
                        decoration: BoxDecoration(
                          color: isLoading
                              ? AppTheme.primaryColor.withAlpha(128)
                              : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withAlpha(77),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.upload,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Submit Data",
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyLarge
                                        ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Success/Error Messages
                  if (successMessage != null)
                    Center(
                      child: Text(
                        successMessage!,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                  if (errorMessage != null)
                    Center(
                      child: Text(
                        errorMessage!,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Latest Emission Data
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Latest Emission Data",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (latestEmission == null)
                            const Center(
                              child: Text(
                                "No emission data available.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else ...[
                            Text(
                              "Institution: ${latestEmission!['institution'] ?? 'N/A'}",
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Site: ${latestEmission!['site']}",
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Primary Source: ${latestEmission!['primary_source']}",
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Primary Amount: ${latestEmission!['primary_amount']} kg/kWh",
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            if (latestEmission!['secondary_source'] != null)
                              Text(
                                "Secondary Source: ${latestEmission!['secondary_source']}",
                                style: AppTheme.lightTheme.textTheme.bodyMedium,
                              ),
                            if (latestEmission!['secondary_source'] != null)
                              const SizedBox(height: 8),
                            if (latestEmission!['secondary_amount'] != null)
                              Text(
                                "Secondary Amount: ${latestEmission!['secondary_amount']} kg/kWh",
                                style: AppTheme.lightTheme.textTheme.bodyMedium,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              "Hours: ${latestEmission!['hours']}",
                              style: AppTheme.lightTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Total Emissions: ${calculateTotalEmissions(latestEmission!).toStringAsFixed(2)} kg CO2",
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Footer
                  Center(
                    child: Text(
                      "Powered by Ecotrack",
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
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
