import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';

// Classes for emission calculation and status
class EmissionCalculator {
  static const double lpgFactor = 3.0; // kg CO2e/kg LPG
  static const double electricityFactor = 0.2; // kg CO2e/kWh (Kenya grid)
  static const double charcoalFactor = 1.8;
  static const double dieselFactor = 2.7;

  double calculateEmission(Map<String, dynamic> emission) {
    final String primarySource = emission['primary_source'] ?? 'Other';
    final double primaryAmount = (emission['primary_amount'] ?? 0.0).toDouble();
    final String? secondarySource = emission['secondary_source'];
    final double secondaryAmount =
        (emission['secondary_amount'] ?? 0.0).toDouble();

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

    return primaryCo2e + secondaryCo2e;
  }
}

class EmissionStatus {
  static const double singleSiteLimit = 500.0; // kg CO2e/month for one site
  static const double multiSiteLimit = 5000.0; // kg CO2e/month for all sites

  String classify(double totalCo2e, {bool isSingleSite = true}) {
    double limit = isSingleSite ? singleSiteLimit : multiSiteLimit;
    if (isSingleSite) {
      if (totalCo2e < 200) return 'Low';
      if (totalCo2e <= 500) return 'Typical';
      return 'High';
    } else {
      if (totalCo2e < 3500) return 'Good';
      if (totalCo2e <= 5000) return 'Moderate';
      if (totalCo2e <= 7500) return 'Bad';
      return 'Critical';
    }
  }

  double percentOverLimit(double totalCo2e, {bool isSingleSite = true}) {
    double limit = isSingleSite ? singleSiteLimit : multiSiteLimit;
    return ((totalCo2e - limit) / limit * 100).clamp(0, double.infinity);
  }
}

class RecommendationEngine {
  String getRecommendation(
      String status, List<Map<String, dynamic>> emissions) {
    if (emissions.isEmpty) {
      return 'Welcome! Get started by logging your emission data.';
    }
    if (status == 'Low' || status == 'Good') {
      return 'Great job! Maintain efficient energy use.';
    }
    if (status == 'Typical') {
      return 'Emissions are typical. Consider renewable energy to reduce further.';
    }
    final highLpgSites = emissions
        .where((e) =>
            e['primary_source'] == 'LPG' && (e['primary_amount'] ?? 0) > 20)
        .toList();
    if (highLpgSites.isNotEmpty) {
      return 'High LPG use in ${highLpgSites.map((e) => e['site']).join(', ')}. '
          'Explore biogas from food waste or solar alternatives.';
    }
    return 'Reduce emissions by optimizing operations or switching to cleaner energy.';
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
        final co2e = item['co2e_monthly'] ?? calculator.calculateEmission(item);
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
        status = emissionStatus.classify(totalCo2e,
            isSingleSite: emissions.length <= 1);
        percentOverLimit = emissionStatus.percentOverLimit(totalCo2e,
            isSingleSite: emissions.length <= 1);
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

  Color getEmissionColor(double co2e, {bool isSingleSite = true}) {
    if (isSingleSite) {
      if (co2e < 200) return Colors.green;
      if (co2e <= 500) return Colors.blue;
      return Colors.red;
    } else {
      if (co2e < 3500) return Colors.green;
      if (co2e <= 5000) return Colors.orange;
      if (co2e <= 7500) return Colors.red;
      return Colors.red[900]!;
    }
  }

  String getUnitForSource(String? source) {
    switch (source) {
      case 'LPG':
      case 'Charcoal':
      case 'Diesel':
        return 'kg';
      case 'Electricity':
        return 'kWh';
      default:
        return 'units';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSingleSite = emissions.length <= 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Monthly Emissions
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.co2, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Total Monthly Emissions: ${totalCo2e.toStringAsFixed(1)} kg CO2e",
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        "Status: $status",
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          color: status == 'Typical' || status == 'Good'
                              ? Colors.blue
                              : status == 'Low'
                                  ? Colors.green
                                  : status == 'Moderate'
                                      ? Colors.orange
                                      : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Emission vs. Limit (Radial Gauge)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSingleSite
                              ? "Emission vs. Limit (500 kg)"
                              : "Emission vs. Limit (5 tons)",
                          style: AppTheme.lightTheme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: gauges.SfRadialGauge(
                      axes: <gauges.RadialAxis>[
                        gauges.RadialAxis(
                          minimum: 0,
                          maximum: isSingleSite ? 600 : 7500,
                          startAngle: 270,
                          endAngle: 270,
                          showLabels: false,
                          radiusFactor: 0.8,
                          axisLineStyle: gauges.AxisLineStyle(
                            thickness: 0.1,
                            thicknessUnit: gauges.GaugeSizeUnit.factor,
                            color: Colors.grey[300],
                          ),
                          pointers: <gauges.GaugePointer>[
                            gauges.RangePointer(
                              value:
                                  totalCo2e.clamp(0, isSingleSite ? 600 : 7500),
                              width: 0.1,
                              sizeUnit: gauges.GaugeSizeUnit.factor,
                              gradient: SweepGradient(
                                colors: totalCo2e > (isSingleSite ? 500 : 5000)
                                    ? [Colors.redAccent, Colors.red]
                                    : [Colors.blueAccent, Colors.blue],
                              ),
                              enableAnimation: true,
                              animationDuration: 1000,
                              animationType: gauges.AnimationType.ease,
                            ),
                          ],
                          annotations: <gauges.GaugeAnnotation>[
                            gauges.GaugeAnnotation(
                              widget: Text(
                                isSingleSite
                                    ? '${(totalCo2e / 500 * 100).toStringAsFixed(1)}%'
                                    : '${(totalCo2e / 5000 * 100).toStringAsFixed(1)}%',
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
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSingleSite
                              ? 'Limit Exceedance: ${percentOverLimit.toStringAsFixed(1)}% over 500 kg'
                              : 'Limit Exceedance: ${percentOverLimit.toStringAsFixed(1)}% over 5000 kg',
                          style: AppTheme.lightTheme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Emissions by Site (Bar Chart)
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Emissions by Site (kg CO2e):",
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          emissions.isEmpty
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                          "No data available. Start logging your emissions."),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobilePortrait = constraints.maxWidth < 600 ||
                        MediaQuery.of(context).orientation ==
                            Orientation.portrait;
                    final chartHeight = isMobilePortrait ? 200.0 : 300.0;
                    final barWidthFactor = isMobilePortrait ? 3.0 : 2.5;
                    final legendSpacing = isMobilePortrait ? 6.0 : 8.0;
                    final legendRunSpacing = isMobilePortrait ? 4.0 : 4.0;
                    final chartLegendSpacing = isMobilePortrait ? 16.0 : 12.0;

                    return Column(
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side:
                                BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: chartHeight,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: emissions.isNotEmpty
                                      ? (emissions
                                              .map((e) =>
                                                  e['co2e_monthly'] as double)
                                              .reduce((a, b) => a > b ? a : b) *
                                          1.2)
                                      : (isSingleSite ? 600 : 5000),
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
                                        final site =
                                            emissions[groupIndex]['site'];
                                        final value =
                                            rod.toY.toStringAsFixed(1);
                                        return BarTooltipItem(
                                          '$site\n$value kg CO2e',
                                          AppTheme
                                              .lightTheme.textTheme.bodySmall!
                                              .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize:
                                                isMobilePortrait ? 10 : 12,
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
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: SizedBox(
                                              width: 60,
                                              child: Text(
                                                emissions[index]['site'],
                                                style: AppTheme.lightTheme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  fontSize: isMobilePortrait
                                                      ? 10
                                                      : 12,
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
                                              fontSize:
                                                  isMobilePortrait ? 10 : 12,
                                            ),
                                          );
                                        },
                                        interval: emissions.isNotEmpty
                                            ? (emissions
                                                    .map((e) =>
                                                        e['co2e_monthly']
                                                            as double)
                                                    .reduce((a, b) =>
                                                        a > b ? a : b) /
                                                5)
                                            : (isSingleSite ? 100 : 1000),
                                      ),
                                    ),
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey[200]!,
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups:
                                      emissions.asMap().entries.map((entry) {
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
                                              getEmissionColor(co2e,
                                                      isSingleSite:
                                                          isSingleSite)
                                                  .withAlpha(200),
                                              getEmissionColor(co2e,
                                                  isSingleSite: isSingleSite),
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          width: screenWidth /
                                              (emissions.length *
                                                  barWidthFactor),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(8)),
                                          backDrawRodData:
                                              BackgroundBarChartRodData(
                                            show: true,
                                            toY: emissions.isNotEmpty
                                                ? (emissions
                                                        .map((e) =>
                                                            e['co2e_monthly']
                                                                as double)
                                                        .reduce((a, b) =>
                                                            a > b ? a : b) *
                                                    1.2)
                                                : (isSingleSite ? 600 : 5000),
                                            color: Colors.grey[100],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: chartLegendSpacing),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: legendSpacing,
                          runSpacing: legendRunSpacing,
                          children: isSingleSite
                              ? [
                                  _buildLegendItem(
                                      Colors.green, 'Low (<200 kg)'),
                                  _buildLegendItem(
                                      Colors.blue, 'Typical (200-500 kg)'),
                                  _buildLegendItem(
                                      Colors.red, 'High (>500 kg)'),
                                ]
                              : [
                                  _buildLegendItem(
                                      Colors.green, 'Good (<3500 kg)'),
                                  _buildLegendItem(
                                      Colors.orange, 'Moderate (3500-5000 kg)'),
                                  _buildLegendItem(
                                      Colors.red, 'Bad (5000-7500 kg)'),
                                  _buildLegendItem(
                                      Colors.red[900]!, 'Critical (>7500 kg)'),
                                ],
                        ),
                      ],
                    );
                  },
                ),
          const SizedBox(height: 16),

          // Tabbed Section for Site Details and Recommendations
          Row(
            children: [
              Icon(Icons.insights, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Details & Insights:",
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
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
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      emissions.isEmpty
                          ? const Center(child: Text("No site data available."))
                          : ListView(
                              children: emissions
                                  .map((e) => ListTile(
                                        leading: Icon(Icons.location_on,
                                            size: 20, color: Colors.grey[600]),
                                        title: Text(
                                          '${e['site']}: ${e['co2e_monthly'].toStringAsFixed(1)} kg CO2e',
                                          style: AppTheme
                                              .lightTheme.textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        subtitle: Text(
                                          'Primary: ${e['primary_source'] ?? 'N/A'} ${e['primary_amount'] ?? 0.0} ${getUnitForSource(e['primary_source'])}\n'
                                          'Hours: ${e['hours'] ?? 0.0}',
                                          style: AppTheme
                                              .lightTheme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ))
                                  .toList(),
                            ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
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
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobilePortrait = constraints.maxWidth < 600 ||
            MediaQuery.of(context).orientation == Orientation.portrait;
        final fontSize = isMobilePortrait ? 10.0 : 12.0;
        final dotSize = isMobilePortrait ? 12.0 : 16.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                fontSize: fontSize,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        );
      },
    );
  }
}
