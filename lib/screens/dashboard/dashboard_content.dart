import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

// Classes for emission calculation and status
class EmissionCalculator {
  static const double lpgFactor = 3.0; // kg CO2e/kg LPG
  static const double electricityFactor = 0.4; // kg CO2e/kWh
  static const double charcoalFactor = 1.5;
  static const double dieselFactor = 2.68;
  static const double poultryMethaneFactor = 0.02;
  static const double poultryN2OFactor = 0.01;

  double calculateRestaurant(double lpgKg, [double kWh = 0.0]) =>
      lpgKg * lpgFactor + kWh * electricityFactor;
  double calculateKitchen(double lpgKg, double charcoalKg) =>
      lpgKg * lpgFactor + charcoalKg * charcoalFactor;
  double calculateLabs(double kWh, double lpgKg) =>
      kWh * electricityFactor + lpgKg * lpgFactor;
  double calculatePoultry(double birdCount, double kWh) {
    double manureKg = birdCount * 0.5;
    return (manureKg * poultryMethaneFactor * 25) +
        (manureKg * poultryN2OFactor * 298) +
        kWh * electricityFactor;
  }

  double calculateTransport(double dieselLiters) => dieselLiters * dieselFactor;
}

class EmissionStatus {
  static const double limit = 1000.0; // 1 ton CO2e/month

  String classify(double totalCo2e) {
    if (totalCo2e < 700) return 'Good';
    if (totalCo2e <= 1000) return 'Moderate';
    if (totalCo2e <= 1500) return 'Bad';
    return 'Critical';
  }

  double percentOverLimit(double totalCo2e) =>
      ((totalCo2e - limit) / limit * 100).clamp(0, double.infinity);
}

class RecommendationEngine {
  String getRecommendation(
      String status, List<Map<String, dynamic>> emissions) {
    if (status == 'Good') return 'Great job! Maintain efficient energy use.';
    final highLpgSites = emissions
        .where((e) =>
            e['primary_energy'] == 'LPG' && (e['primary_amount'] ?? 0) > 20)
        .toList();
    if (highLpgSites.isNotEmpty) {
      return 'High LPG use in ${highLpgSites.map((e) => e['site']).join(', ')}. '
          'Consider switching to biogas from food waste.';
    }
    return 'Reduce emissions by exploring solar energy or optimizing operations.';
  }
}

class DashboardContent extends StatefulWidget {
  final Function(List<Map<String, dynamic>>, String) onDataFetched;

  const DashboardContent({super.key, required this.onDataFetched});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> emissions = [];
  double totalCo2e = 0.0;
  String status = '';
  double percentOverLimit = 0.0;
  String briefRecommendation = '';

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      final response = await supabase
          .from('emissions')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        emissions = response;
        totalCo2e = emissions.fold(
            0.0, (sum, item) => sum + (item['co2e_monthly'] ?? 0.0));
        final emissionStatus = EmissionStatus();
        status = emissionStatus.classify(totalCo2e);
        percentOverLimit = emissionStatus.percentOverLimit(totalCo2e);
        briefRecommendation =
            RecommendationEngine().getRecommendation(status, emissions);
        widget.onDataFetched(emissions, status);
      });
    } catch (error) {
      print("Error fetching dashboard data: $error");
      setState(() {
        emissions = [];
        totalCo2e = 0.0;
        status = 'Error';
        briefRecommendation = 'Unable to fetch recommendations.';
      });
      widget.onDataFetched(emissions, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Total Monthly Emissions: ${totalCo2e.toStringAsFixed(1)} kg CO2e",
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Status: $status",
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: status == 'Good'
                          ? Colors.green
                          : status == 'Moderate'
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Emission vs. Limit (1 ton)",
                    style: AppTheme.lightTheme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: CircularProgressIndicator(
                          value: totalCo2e / 1000,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              totalCo2e > 1000 ? Colors.red : Colors.green),
                        ),
                      ),
                      Text(
                        '${(totalCo2e / 1000 * 100).toStringAsFixed(1)}%',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Limit Exceedance: ${percentOverLimit.toStringAsFixed(1)}% over 1000 kg',
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            "Emissions by Site (kg CO2e):",
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? const Center(child: Text("No data available."))
              : Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: emissions
                                  .map((e) => (e['co2e_monthly'] ?? 0.0))
                                  .reduce((a, b) => a > b ? a : b) *
                              1.2,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final site = emissions[value.toInt()]['site'];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      site.length > 10
                                          ? site.substring(0, 10) + '...'
                                          : site,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: emissions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data['co2e_monthly']?.toDouble() ?? 0.0,
                                  color: Colors.blue,
                                  width: 16,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 16),

          Text(
            "Site Details:",
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? const Center(child: Text("No site data available."))
              : Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: emissions
                          .map((e) => ListTile(
                                title: Text(
                                  '${e['site']}: ${e['co2e_monthly']?.toStringAsFixed(1)} kg CO2e',
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  'Primary: ${e['primary_energy']} ${e['primary_amount']} ${e['primary_unit']}',
                                  style:
                                      AppTheme.lightTheme.textTheme.bodySmall,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
          const SizedBox(height: 16),

          Text(
            "Quick Recommendation:",
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                briefRecommendation,
                style: AppTheme.lightTheme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
