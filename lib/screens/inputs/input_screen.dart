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

  final _siteController = TextEditingController();
  String? _primarySource;
  final _primaryAmountController = TextEditingController();
  String? _secondarySource;
  final _secondaryAmountController = TextEditingController();
  String? _replenish;
  final _customReplenishController = TextEditingController();
  final _hoursController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;
  bool hasSubmitted = false;

  final List<String> energySources = ['LPG', 'Charcoal', 'Electricity', 'Diesel', 'Other'];
  final List<String> replenishOptions = ['Per Day', 'Daily', 'Weekly', 'Monthly', 'Other'];

  List<String> getAvailableSecondarySources() {
    if (_primarySource == null) {
      return energySources;
    }
    return energySources.where((source) => source != _primarySource).toList();
  }

  @override
  void dispose() {
    _siteController.dispose();
    _primaryAmountController.dispose();
    _secondaryAmountController.dispose();
    _customReplenishController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> submitEmissionData() async {
    setState(() {
      hasSubmitted = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
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

      final String replenishValue = _replenish == 'Other'
          ? _customReplenishController.text.trim()
          : _replenish!;

      // Prepare data for submission
      final emissionData = {
        'user_id': user.id,
        'site': _siteController.text.trim(),
        'primary_source': _primarySource,
        'primary_amount': double.parse(_primaryAmountController.text.trim()),
        'secondary_source': _secondarySource,
        'secondary_amount': _secondaryAmountController.text.isNotEmpty
            ? double.parse(_secondaryAmountController.text.trim())
            : null,
        'replenish': replenishValue,
        'hours': double.parse(_hoursController.text.trim()),
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
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Log Emission Data",
                style: AppTheme.lightTheme.appBarTheme.titleTextStyle,
              ),
            ),
          ),
          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
    
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
            
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
                  const SizedBox(height: 40),
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
