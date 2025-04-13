import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'package:fl_chart/fl_chart.dart';
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
        primaryCo2e = 0.0;
    }

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

    return (primaryCo2e + secondaryCo2e) * hours;
  }
}

class EmissionStatus {
  static const double limit = 5000.0; // Updated to 5 tons CO2e/month

  String classify(double totalCo2e) {
    if (totalCo2e < 3500) return 'Good'; // Adjusted thresholds
    if (totalCo2e <= 5000) return 'Moderate';
    if (totalCo2e <= 7500) return 'Bad';
    return 'Critical';
  }

  double percentOverLimit(double totalCo2e) =>
      ((totalCo2e - limit) / limit * 100).clamp(0, double.infinity);
}

class RecommendationEngine {
  String getRecommendation(
      String status, List<Map<String, dynamic>> emissions) {
    if (emissions.isEmpty) {
      return 'Welcome! Get started by logging your emission data.';
    }
    if (status == 'Good') {
      return 'Great job! Maintain efficient energy use.';
    }
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

class _DashboardContentState extends State<DashboardContent>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> emissions = [];
  double totalCo2e = 0.0;
  String status = '';
  double percentOverLimit = 0.0;
  String briefRecommendation = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Color getEmissionColor(double co2e) {
    if (co2e < 3500) return Colors.green;
    if (co2e <= 5000) return Colors.orange;
    if (co2e <= 7500) return Colors.red;
    return Colors.red[900]!;
  }

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
        return 'units';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Monthly Emissions
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
          const SizedBox(height: 24),

          // Emission vs. Limit (Radial Gauge)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Emission vs. Limit (5 tons)",
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  width: 150,
                  child: gauges.SfRadialGauge(
                    axes: <gauges.RadialAxis>[
                      gauges.RadialAxis(
                        minimum: 0,
                        maximum: 7500,
                        startAngle: 270,
                        endAngle: 270,
                        showLabels: false,
                        showTicks: false,
                        radiusFactor: 0.8,
                        axisLineStyle: gauges.AxisLineStyle(
                          thickness: 0.1,
                          thicknessUnit: gauges.GaugeSizeUnit.factor,
                          color: Colors.grey[300],
                        ),
                        pointers: <gauges.GaugePointer>[
                          gauges.RangePointer(
                            value: totalCo2e.clamp(0, 7500),
                            width: 0.1,
                            sizeUnit: gauges.GaugeSizeUnit.factor,
                            gradient: SweepGradient(
                              colors: totalCo2e > 5000
                                  ? [Colors.redAccent, Colors.red]
                                  : [Colors.greenAccent, Colors.green],
                            ),
                            enableAnimation: true,
                            animationDuration: 1000,
                            animationType: gauges.AnimationType.ease,
                          ),
                        ],
                        annotations: <gauges.GaugeAnnotation>[
                          gauges.GaugeAnnotation(
                            widget: Text(
                              '${(totalCo2e / 5000 * 100).toStringAsFixed(1)}%',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            angle: 90,
                            positionFactor: 0.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Limit Exceedance: ${percentOverLimit.toStringAsFixed(1)}% over 5000 kg',
                  style: AppTheme.lightTheme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Emissions by Site (Modern Bar Chart with fl_chart)
          Text(
            "Emissions by Site (kg CO2e):",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                        "No data available. Start logging your emissions."),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.grey[50]!,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(25),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 300,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: emissions.isNotEmpty
                                ? (emissions
                                        .map((e) => e['co2e_monthly'] as double)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.2)
                                : 5000,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipRoundedRadius: 8,
                                tooltipPadding: const EdgeInsets.all(8),
                                tooltipMargin: 8,
                                getTooltipColor: (_) =>
                                    Colors.grey[800]!.withAlpha(200),
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  if (groupIndex < 0 ||
                                      groupIndex >= emissions.length) {
                                    return null;
                                  }
                                  final site = emissions[groupIndex]['site'];
                                  final value = rod.toY.toStringAsFixed(1);
                                  return BarTooltipItem(
                                    '$site\n$value kg CO2e',
                                    AppTheme.lightTheme.textTheme.bodySmall!
                                        .copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 ||
                                        index >= emissions.length) {
                                      return const SizedBox();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        width: 60,
                                        child: Text(
                                          emissions[index]['site'],
                                          style: AppTheme
                                              .lightTheme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: AppTheme
                                          .lightTheme.textTheme.bodySmall
                                          ?.copyWith(
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                  interval: emissions.isNotEmpty
                                      ? (emissions
                                              .map((e) =>
                                                  e['co2e_monthly'] as double)
                                              .reduce((a, b) => a > b ? a : b) /
                                          5)
                                      : 1000,
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[200],
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: emissions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final co2e = data['co2e_monthly'] as double;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: co2e,
                                    gradient: LinearGradient(
                                      colors: [
                                        getEmissionColor(co2e).withAlpha(200),
                                        getEmissionColor(co2e),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width:
                                        screenWidth / (emissions.length * 2.5),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: emissions.isNotEmpty
                                          ? (emissions
                                                  .map((e) => e['co2e_monthly']
                                                      as double)
                                                  .reduce(
                                                      (a, b) => a > b ? a : b) *
                                              1.2)
                                          : 5000,
                                      color: Colors.grey[100],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          swapAnimationDuration:
                              const Duration(milliseconds: 500),
                          swapAnimationCurve: Curves.easeInOut,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildLegendItem(Colors.green, 'Good (<3500 kg)'),
                        _buildLegendItem(
                            Colors.orange, 'Moderate (3500-5000 kg)'),
                        _buildLegendItem(Colors.red, 'Bad (5000-7500 kg)'),
                        _buildLegendItem(
                            Colors.red[900]!, 'Critical (>7500 kg)'),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Tabbed Section for Site Details and Recommendations
          Text(
            "Details & Insights:",
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Theme.of(context).primaryColor,
                  labelStyle:
                      AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: "Site Details"),
                    Tab(text: "Recommendations"),
                  ],
                ),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(8.0),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      emissions.isEmpty
                          ? const Center(child: Text("No site data available."))
                          : ListView(
                              children: emissions
                                  .map((e) => ListTile(
                                        title: Text(
                                          '${e['site']}: ${e['co2e_monthly'].toStringAsFixed(1)} kg CO2e',
                                          style: AppTheme
                                              .lightTheme.textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        subtitle: Text(
                                          'Primary: ${e['primary_source'] ?? 'N/A'} ${e['primary_amount'] ?? 0.0} ${getUnitForSource(e['primary_source'])}',
                                          style: AppTheme
                                              .lightTheme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ))
                                  .toList(),
                            ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          briefRecommendation,
                          style: AppTheme.lightTheme.textTheme.bodyMedium,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
