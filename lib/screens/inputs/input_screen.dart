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
  Map<String, dynamic>? latestEmission;

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

  // Emission factors (kg CO2e per unit)
  final Map<String, double> emissionFactors = {
    'LPG': 3.0, // kg CO2e/kg
    'Charcoal': 1.8,
    'Electricity': 0.2, // kg CO2e/kWh (Kenya grid)
    'Diesel': 2.7, // kg CO2e/liter
    'Other': 1.0, // Placeholder
  };

  // Get unit for source
  String getUnitForSource(String? source) {
    return source == 'Electricity' ? 'kWh' : 'kg';
  }

  // Filter secondary source options
  List<String> getAvailableSecondarySources() {
    if (_primarySource == null) {
      return energySources;
    }
    return energySources.where((source) => source != _primarySource).toList();
  }

  @override
  void initState() {
    super.initState();
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
    _fetchLatestEmission();
  }

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

  // Check for duplicate site
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

  // Bayesian-inspired anomaly detection
  bool isAnomalous(double co2e) {
    const double priorMean = 350.0; // Typical kitchen emissions (kg CO2e/month)
    const double priorStd = 150.0; // Variability
    double z = (co2e - priorMean) / priorStd;
    return z.abs() > 3; // Adjusted range to handle smaller values
  }

  // Calculate CO2e
  double calculateCo2e(Map<String, dynamic> data) {
    double primaryAmount = data['primary_amount']?.toDouble() ?? 0;
    double secondaryAmount = data['secondary_amount']?.toDouble() ?? 0;
    String primarySource = data['primary_source'] ?? 'Other';
    String secondarySource = data['secondary_source'] ?? 'Other';
    double primaryFactor = emissionFactors[primarySource] ?? 1.0;
    double secondaryFactor = emissionFactors[secondarySource] ?? 1.0;
    return primaryAmount * primaryFactor + secondaryAmount * secondaryFactor;
  }

  double calculateTotalEmissions(Map<String, dynamic> emission) {
    return calculateCo2e(emission);
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

    final site = _siteController.text.trim();
    final emissionData = {
      'user_id': supabase.auth.currentUser!.id,
      'institution': _institution,
      'site': site,
      'primary_source': _primarySource,
      'primary_amount': double.parse(_primaryAmountController.text.trim()),
      'secondary_source': _secondarySource,
      'secondary_amount': _secondaryAmountController.text.isNotEmpty
          ? double.parse(_secondaryAmountController.text.trim())
          : null,
      'replenish': _replenish == 'Other'
          ? _customReplenishController.text.trim()
          : _replenish!,
      'hours': double.parse(_hoursController.text.trim()),
    };

    // Calculate CO2e
    double co2e = calculateCo2e(emissionData);

    // Anomaly detection
    if (isAnomalous(co2e)) {
      setState(() {
        errorMessage =
            "Emission value (${co2e.toStringAsFixed(1)} kg CO2e) is outside typical range (100–600 kg). Please verify.";
        hasSubmitted = false;
      });
      return;
    }

    // Duplicate check
    if (await _checkDuplicateSite(_institution!, site)) {
      setState(() {
        errorMessage =
            "Site '$site' already exists for $_institution. Use a different name or update existing data.";
        hasSubmitted = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final response = await supabase.from('emissions').insert({
        ...emissionData,
        'co2_monthly': co2e,
      }).select();

      if (response.isNotEmpty) {
        setState(() {
          successMessage = "Emission data submitted successfully!";
          isLoading = false;
          hasSubmitted = false;
        });
        _log.info('Emission data submitted: $emissionData');

        // Clear form
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

  void _clearErrorMessage() {
    if (errorMessage != null) {
      setState(() {
        errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSecondarySources = getAvailableSecondarySources();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Log Emission Data"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.school,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Institution",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _institution,
                              decoration: InputDecoration(
                                hintText: "Select institution",
                                prefixIcon: Icon(Icons.school,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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

                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Site",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _siteController,
                              decoration: InputDecoration(
                                hintText: "e.g., Chilton’s Restaurant",
                                prefixIcon: Icon(Icons.location_on,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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

                            Row(
                              children: [
                                Icon(Icons.power,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Primary Energy Source",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _primarySource,
                              decoration: InputDecoration(
                                hintText: "Select primary source",
                                prefixIcon: Icon(Icons.power,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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

                            Row(
                              children: [
                                Icon(Icons.scale,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Primary Amount (${getUnitForSource(_primarySource)})",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _primaryAmountController,
                              decoration: InputDecoration(
                                hintText:
                                    "e.g., 20 ${getUnitForSource(_primarySource)}",
                                prefixIcon: Icon(Icons.scale,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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

                            Row(
                              children: [
                                Icon(Icons.power,
                                    color: AppTheme.accentColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Secondary Energy Source (Optional)",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _secondarySource,
                              decoration: InputDecoration(
                                hintText: "Select secondary source",
                                prefixIcon: Icon(Icons.power,
                                    color: AppTheme.accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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

                            Row(
                              children: [
                                Icon(Icons.scale,
                                    color: AppTheme.accentColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Secondary Amount (${getUnitForSource(_secondarySource)}, Optional)",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _secondaryAmountController,
                              decoration: InputDecoration(
                                hintText:
                                    "e.g., 10 ${getUnitForSource(_secondarySource)}",
                                prefixIcon: Icon(Icons.scale,
                                    color: AppTheme.accentColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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
                                  return null;
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return "Please enter a valid positive number.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Icon(Icons.eco,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Replenish Frequency",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _replenish,
                              decoration: InputDecoration(
                                hintText: "Select frequency",
                                prefixIcon: Icon(Icons.eco,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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
                              Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: AppTheme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Custom Replenish Frequency",
                                      style: AppTheme
                                          .lightTheme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _customReplenishController,
                                decoration: InputDecoration(
                                  hintText: "e.g., Biweekly",
                                  prefixIcon: Icon(Icons.edit,
                                      color: AppTheme.primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
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

                            Row(
                              children: [
                                Icon(Icons.timer,
                                    color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Operational Hours",
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _hoursController,
                              decoration: InputDecoration(
                                hintText: "e.g., 8",
                                prefixIcon: Icon(Icons.timer,
                                    color: AppTheme.primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
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
                  const SizedBox(height: 16),

                  // Submit Button
                  Center(
                    child: GestureDetector(
                      onTap: isLoading ? null : submitEmissionData,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(
                              color: isLoading
                                  ? Colors.grey[400]!
                                  : AppTheme.primaryColor,
                              width: 1),
                        ),
                        color: isLoading
                            ? Colors.grey[200]
                            : AppTheme.primaryColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
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
                  ),
                  const SizedBox(height: 16),

                  // Success/Error Messages
                  if (successMessage != null || errorMessage != null)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal, // Prevent overflow
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (successMessage != null)
                              Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    successMessage!,
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            if (errorMessage != null)
                              Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: AppTheme.errorColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    errorMessage!,
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Latest Emission Data
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobilePortrait = constraints.maxWidth < 600 ||
                          MediaQuery.of(context).orientation ==
                              Orientation.portrait;
                      final titleFontSize = isMobilePortrait ? 16.0 : 18.0;
                      final bodyFontSize = isMobilePortrait ? 14.0 : 16.0;
                      final itemSpacing = isMobilePortrait ? 10.0 : 8.0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.history,
                                      color: AppTheme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Latest Emission Data",
                                      style: AppTheme
                                          .lightTheme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontSize: titleFontSize,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (latestEmission == null)
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "No emission data available.",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: Colors.grey,
                                          fontSize: bodyFontSize,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Row(
                                  children: [
                                    Icon(Icons.school,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Institution: ${latestEmission!['institution'] ?? 'N/A'}",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: itemSpacing),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Site: ${latestEmission!['site']}",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: itemSpacing),
                                Row(
                                  children: [
                                    Icon(Icons.power,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Primary Source: ${latestEmission!['primary_source']}",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: itemSpacing),
                                Row(
                                  children: [
                                    Icon(Icons.scale,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Primary Amount: ${latestEmission!['primary_amount']} ${getUnitForSource(latestEmission!['primary_source'])}",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (latestEmission!['secondary_source'] !=
                                    null) ...[
                                  SizedBox(height: itemSpacing),
                                  Row(
                                    children: [
                                      Icon(Icons.power,
                                          color: AppTheme.accentColor,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Secondary Source: ${latestEmission!['secondary_source']}",
                                          style: AppTheme
                                              .lightTheme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontSize: bodyFontSize,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (latestEmission!['secondary_amount'] !=
                                    null) ...[
                                  SizedBox(height: itemSpacing),
                                  Row(
                                    children: [
                                      Icon(Icons.scale,
                                          color: AppTheme.accentColor,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Secondary Amount: ${latestEmission!['secondary_amount']} ${getUnitForSource(latestEmission!['secondary_source'])}",
                                          style: AppTheme
                                              .lightTheme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontSize: bodyFontSize,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: itemSpacing),
                                Row(
                                  children: [
                                    Icon(Icons.timer,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Hours: ${latestEmission!['hours']}",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: itemSpacing),
                                Row(
                                  children: [
                                    Icon(Icons.co2,
                                        color: AppTheme.primaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Total Emissions: ${(latestEmission!['co2_monthly'] ?? calculateTotalEmissions(latestEmission!)).toStringAsFixed(2)} kg CO2e",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: bodyFontSize,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

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
