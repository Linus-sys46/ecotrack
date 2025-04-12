import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../config/theme.dart';

// Classes for emission calculation and status
class EmissionCalculator {
  static const double lpgFactor = 3.0; // kg CO2e/kg LPG
  static const double electricityFactor = 0.4; // kg CO2e/kWh
  static const double charcoalFactor = 1.5;
  static const double dieselFactor = 2.68;
  static const double poultryMethaneFactor = 0.02;
  static const double poultryN2OFactor = 0.01;

  double calculateEmission(Map<String, dynamic> emission) {
    final String primarySource = emission['primary_source'] ?? 'Other';
    final double primaryAmount = (emission['primary_amount'] ?? 0.0).toDouble();
    final String? secondarySource = emission['secondary_source'];
    final double secondaryAmount =
        (emission['secondary_amount'] ?? 0.0).toDouble();
    final double hours = (emission['hours'] ?? 0.0).toDouble();

    double primaryCo2e = 0.0;
    double secondaryCo2e = 0.0;

    // Calculate CO2e for primary source
    switch (primarySource) {
      case 'LPG':
        primaryCo2e = primaryAmount * lpgFactor;
        break;
      case 'Electricity':
        primaryCo2e = primaryAmount * electricityFactor;
        break;
      case 'Charcoal':
        primaryCo2e = primaryAmount * charcoalFactor;
        break;
      case 'Diesel':
        primaryCo2e = primaryAmount * dieselFactor;
        break;
      default:
        primaryCo2e = 0.0; // Default for 'Other'
    }

    // Calculate CO2e for secondary source (if present)
    if (secondarySource != null) {
      switch (secondarySource) {
        case 'LPG':
          secondaryCo2e = secondaryAmount * lpgFactor;
          break;
        case 'Electricity':
          secondaryCo2e = secondaryAmount * electricityFactor;
          break;
        case 'Charcoal':
          secondaryCo2e = secondaryAmount * charcoalFactor;
          break;
        case 'Diesel':
          secondaryCo2e = secondaryAmount * dieselFactor;
          break;
        default:
          secondaryCo2e = 0.0;
      }
    }

    // Total CO2e = (primary + secondary) * hours
    return (primaryCo2e + secondaryCo2e) * hours;
  }
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
            e['primary_source'] == 'LPG' && (e['primary_amount'] ?? 0) > 20)
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

      final calculator = EmissionCalculator();
      final List<Map<String, dynamic>> updatedEmissions = response.map((item) {
        final co2e = calculator.calculateEmission(item);
        return {
          ...item,
          'co2e_monthly': co2e,
        };
      }).toList();

      setState(() {
        emissions = updatedEmissions;
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

  // Helper method to determine bar color based on emission status
  Color getEmissionColor(double co2e) {
    if (co2e < 700) return Colors.green; // Good
    if (co2e <= 1000) return Colors.orange; // Moderate
    if (co2e <= 1500) return Colors.red; // Bad
    return Colors.red[900]!; // Critical (Dark Red)
  }

  // Helper method to determine the unit based on the primary source
  String getUnitForSource(String? source) {
    switch (source) {
      case 'LPG':
        return 'kg';
      case 'Electricity':
        return 'kWh';
      case 'Charcoal':
        return 'kg';
      case 'Diesel':
        return 'kg';
      default:
        return 'units'; // Default for 'Other' or null
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive adjustments
    final double screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Monthly Emissions
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

          // Emission vs. Limit (Radial Gauge)
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

          // Emissions by Site (Vertical Bar Chart)
          Text(
            "Emissions by Site (kg CO2e):",
            style: AppTheme.lightTheme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? const Center(child: Text("No data available."))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: SizedBox(
                        height: 300, // Fixed height for vertical chart
                        child: SfCartesianChart(
                          primaryXAxis: CategoryAxis(
                            labelStyle: const TextStyle(fontSize: 12),
                            labelRotation:
                                45, // Rotate labels for better readability
                            majorGridLines: const MajorGridLines(width: 0),
                            maximumLabelWidth:
                                screenWidth / (emissions.length + 1),
                          ),
                          primaryYAxis: NumericAxis(
                            labelStyle: const TextStyle(fontSize: 12),
                            title: AxisTitle(
                              text: 'Emissions (kg CO2e)',
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                            majorGridLines: const MajorGridLines(width: 0.5),
                          ),
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            header: 'Emissions',
                            format: 'point.x: point.y kg CO2e',
                          ),
                          series: <CartesianSeries>[
                            ColumnSeries<Map<String, dynamic>, String>(
                              dataSource: emissions
                                ..sort((a, b) => (b['co2e_monthly'] as double)
                                    .compareTo(a['co2e_monthly'] as double)),
                              xValueMapper: (Map<String, dynamic> data, _) =>
                                  data['site'],
                              yValueMapper: (Map<String, dynamic> data, _) =>
                                  data['co2e_monthly'] as double,
                              pointColorMapper:
                                  (Map<String, dynamic> data, _) =>
                                      getEmissionColor(
                                          data['co2e_monthly'] as double),
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelAlignment: ChartDataLabelAlignment.top,
                                textStyle: TextStyle(fontSize: 12),
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              width: 0.6, // Adjust bar width for better spacing
                              spacing: 0.2, // Add spacing between bars
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Legend for Emission Status (using Wrap to prevent overflow)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8, // Horizontal spacing between items
                      runSpacing: 4, // Vertical spacing between lines
                      children: [
                        _buildLegendItem(Colors.green, 'Good (<700 kg)'),
                        _buildLegendItem(
                            Colors.orange, 'Moderate (700-1000 kg)'),
                        _buildLegendItem(Colors.red, 'Bad (1000-1500 kg)'),
                        _buildLegendItem(
                            Colors.red[900]!, 'Critical (>1500 kg)'),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 16),

          // Site Details
          Text(
            "Site Details:",
            style: AppTheme.lightTheme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? const Center(child: Text("No site data available."))
              : Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Column(
                    children: emissions
                        .map((e) => ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${e['site']}: ${e['co2e_monthly'].toStringAsFixed(1)} kg CO2e',
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Primary: ${e['primary_source'] ?? 'N/A'} ${e['primary_amount'] ?? 0.0} ${getUnitForSource(e['primary_source'])}',
                                      style: AppTheme
                                          .lightTheme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
          const SizedBox(height: 16),

          // Quick Recommendation
          Text(
            "Quick Recommendation:",
            style: AppTheme.lightTheme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Text(
              briefRecommendation,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build legend items
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Minimize the Row's size to fit content
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
