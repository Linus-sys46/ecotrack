import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';

class EmissionCalculator {
  static const double lpgFactor = 3.0; // kg CO2e/kg LPG
  static const double electricityFactor = 0.2; // kg CO2e/kWh (Kenya grid)
  static const double charcoalFactor = 1.8;
  static const double dieselFactor = 2.7;

  double calculateEmissionForSource(String? source, double amount) {
    switch (source) {
      case 'LPG':
        return amount * lpgFactor;
      case 'Electricity':
        return amount * electricityFactor;
      case 'Charcoal':
        return amount * charcoalFactor;
      case 'Diesel':
        return amount * dieselFactor;
      default:
        return 0.0;
    }
  }
}

class InsightsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> emissions;
  final String status;

  const InsightsScreen({
    super.key,
    required this.emissions,
    required this.status,
  });

  double getTotalEmissions() {
    return emissions.fold(
        0.0, (sum, item) => sum + (item['co2_monthly']?.toDouble() ?? 0.0));
  }

  Map<String, double> getMonthlyEmissions() {
    Map<String, double> monthlyData = {};
    for (var entry in emissions) {
      if (entry['created_at'] != null) {
        try {
          DateTime date = DateTime.parse(entry['created_at']);
          String monthKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}";
          monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) +
              (entry['co2_monthly']?.toDouble() ?? 0.0);
        } catch (e) {
          print(
              "Error parsing date for entry: ${entry['created_at']}, error: $e");
          continue;
        }
      }
    }
    
    return monthlyData;
  }

  Map<String, double> getEmissionsBySource() {
    Map<String, double> sourceData = {};
    final calculator = EmissionCalculator();

    for (var entry in emissions) {
      final String primarySource = entry['primary_source'] ?? 'Unknown';
      final double primaryAmount = (entry['primary_amount'] ?? 0.0).toDouble();
      final String? secondarySource = entry['secondary_source'];
      final double secondaryAmount =
          (entry['secondary_amount'] ?? 0.0).toDouble();
      final double totalCo2e = entry['co2_monthly']?.toDouble() ?? 0.0;

      double primaryCo2e = entry['co2_monthly'] != null
          ? totalCo2e
          : calculator.calculateEmissionForSource(primarySource, primaryAmount);
      double secondaryCo2e = 0.0;

      if (secondarySource != null && secondaryAmount > 0) {
        if (entry['co2_monthly'] != null) {
          double totalAmount = primaryAmount + secondaryAmount;
          if (totalAmount > 0) {
            primaryCo2e = totalCo2e * (primaryAmount / totalAmount);
            secondaryCo2e = totalCo2e * (secondaryAmount / totalAmount);
          }
        } else {
          secondaryCo2e = calculator.calculateEmissionForSource(
              secondarySource, secondaryAmount);
          primaryCo2e = calculator.calculateEmissionForSource(
              primarySource, primaryAmount);
        }
      }

      sourceData[primarySource] =
          (sourceData[primarySource] ?? 0.0) + primaryCo2e;
      if (secondarySource != null && secondaryCo2e > 0) {
        sourceData[secondarySource] =
            (sourceData[secondarySource] ?? 0.0) + secondaryCo2e;
      }
    }
    return sourceData;
  }

  @override
  Widget build(BuildContext context) {
    final totalEmissions = getTotalEmissions();
    final monthlyEmissions = getMonthlyEmissions();
    final emissionsBySource = getEmissionsBySource();
    final bool isSingleSite = emissions.length <= 1;

    final sortedMonths = monthlyEmissions.keys.toList()..sort();
    final monthlyValues = sortedMonths.isNotEmpty
        ? sortedMonths
            .map((month) => monthlyEmissions[month]!.toDouble())
            .toList()
        : <double>[];
    final int labelInterval = sortedMonths.isNotEmpty
        ? (sortedMonths.length / 5).ceil().clamp(1, sortedMonths.length)
        : 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Insights"),
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
                  // Overview Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
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
                              Icon(Icons.analytics,
                                  color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Overview",
                                  style: AppTheme
                                      .lightTheme.textTheme.titleLarge
                                      ?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.eco,
                                  color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Total Emissions: ${totalEmissions.toStringAsFixed(1)} kg CO2e",
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppTheme.accentColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Status: $status",
                                  style: AppTheme.lightTheme.textTheme.bodyLarge
                                      ?.copyWith(
                                    color:
                                        status == 'Typical' || status == 'Good'
                                            ? Colors.blue
                                            : status == 'Low'
                                                ? Colors.green
                                                : status == 'Moderate'
                                                    ? Colors.orange
                                                    : Colors.red,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emissions Trend Over Time
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
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
                              Icon(Icons.trending_up,
                                  color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Emissions Trend Over Time",
                                  style: AppTheme
                                      .lightTheme.textTheme.titleLarge
                                      ?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          monthlyEmissions.isEmpty
                              ? Row(
                                  children: [
                                    Icon(Icons.warning_amber,
                                        color: AppTheme.accentColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "No trend data available.",
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox(
                                  height: 200,
                                  child: LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: 200,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: Colors.grey[200]!,
                                            strokeWidth: 1,
                                          );
                                        },
                                      ),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) =>
                                                Text(
                                              value.toStringAsFixed(0),
                                              style: AppTheme.lightTheme
                                                  .textTheme.bodySmall,
                                            ),
                                            interval: monthlyValues.isNotEmpty
                                                ? (monthlyValues.reduce(
                                                            (a, b) =>
                                                                a > b ? a : b) *
                                                        0.25)
                                                    .toDouble()
                                                : 200,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: labelInterval.toDouble(),
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      sortedMonths.length) {
                                                return const SizedBox.shrink();
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Text(
                                                  sortedMonths[index],
                                                  style: AppTheme.lightTheme
                                                      .textTheme.bodySmall,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                        rightTitles: AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: monthlyValues
                                              .asMap()
                                              .entries
                                              .map((entry) => FlSpot(
                                                    entry.key.toDouble(),
                                                    entry.value,
                                                  ))
                                              .toList(),
                                          isCurved: true,
                                          color: AppTheme.primaryColor,
                                          barWidth: 3,
                                          dotData: FlDotData(show: true),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppTheme.primaryColor
                                                .withAlpha(51),
                                          ),
                                        ),
                                      ],
                                      minY: 0,
                                      maxY: monthlyValues.isNotEmpty
                                          ? monthlyValues.reduce(
                                                  (a, b) => a > b ? a : b) *
                                              1.2
                                          : (isSingleSite ? 600 : 5000),
                                    ),
                                    // Removed invalid parameter
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emissions by Source
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobilePortrait = constraints.maxWidth < 600 ||
                              MediaQuery.of(context).orientation ==
                                  Orientation.portrait;
                          final chartHeight = isMobilePortrait ? 150.0 : 200.0;
                          final chartRadius = isMobilePortrait ? 60.0 : 90.0;
                          final centerSpaceRadius =
                              isMobilePortrait ? 30.0 : 40.0;
                          final legendFontSize = isMobilePortrait ? 12.0 : 14.0;
                          final legendSpacing = isMobilePortrait ? 6.0 : 8.0;
                          final legendRunSpacing = isMobilePortrait ? 6.0 : 8.0;
                          final chartLegendSpacing =
                              isMobilePortrait ? 16.0 : 12.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.pie_chart,
                                      color: AppTheme.primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Emissions by Source",
                                      style: AppTheme
                                          .lightTheme.textTheme.titleLarge
                                          ?.copyWith(
                                        color: AppTheme.primaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              emissionsBySource.isEmpty
                                  ? Row(
                                      children: [
                                        Icon(Icons.warning_amber,
                                            color: AppTheme.accentColor,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "No source data available.",
                                            style: AppTheme.lightTheme.textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: SizedBox(
                                        height: chartHeight,
                                        child: PieChart(
                                          PieChartData(
                                            sections: emissionsBySource.entries
                                                .map((entry) {
                                              final index = emissionsBySource
                                                  .keys
                                                  .toList()
                                                  .indexOf(entry.key);
                                              return PieChartSectionData(
                                                color: AppTheme.chartColors[
                                                    index %
                                                        AppTheme.chartColors
                                                            .length],
                                                value: entry.value,
                                                title:
                                                    "${(entry.value / totalEmissions * 100).toStringAsFixed(1)}%",
                                                radius: chartRadius,
                                                titleStyle: AppTheme.lightTheme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.white,
                                                  fontSize: isMobilePortrait
                                                      ? 8.0
                                                      : 10.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                titlePositionPercentageOffset:
                                                    0.6,
                                              );
                                            }).toList(),
                                            sectionsSpace: 2,
                                            centerSpaceRadius:
                                                centerSpaceRadius,
                                          ),
                                        ),
                                      ),
                                    ),
                              SizedBox(height: chartLegendSpacing),
                              Wrap(
                                spacing: legendSpacing,
                                runSpacing: legendRunSpacing,
                                alignment: WrapAlignment.center,
                                children: emissionsBySource.keys.map((source) {
                                  final index = emissionsBySource.keys
                                      .toList()
                                      .indexOf(source);
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        color: AppTheme.chartColors[index %
                                            AppTheme.chartColors.length],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        source,
                                        style: AppTheme
                                            .lightTheme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontSize: legendFontSize,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comparison with Average
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
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
                              Icon(Icons.compare_arrows,
                                  color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Comparison with Average",
                                  style: AppTheme
                                      .lightTheme.textTheme.titleLarge
                                      ?.copyWith(
                                    color: AppTheme.primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.eco,
                                  color: AppTheme.accentColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Your Emissions: ${totalEmissions.toStringAsFixed(1)} kg CO2e",
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.recommend,
                                  color: AppTheme.secondaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isSingleSite
                                      ? "Recommended: 350 kg CO2e"
                                      : "Recommended: 3500 kg CO2e",
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                  totalEmissions > (isSingleSite ? 350 : 3500)
                                      ? Icons.warning_amber
                                      : Icons.check_circle_outline,
                                  color: totalEmissions >
                                          (isSingleSite ? 350 : 3500)
                                      ? AppTheme.errorColor
                                      : Colors.green,
                                  size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isSingleSite
                                      ? totalEmissions > 350
                                          ? "Your emissions are ${(totalEmissions - 350).toStringAsFixed(1)} kg above average."
                                          : "Your emissions are ${(350 - totalEmissions).toStringAsFixed(1)} kg below average."
                                      : totalEmissions > 3500
                                          ? "Your emissions are ${(totalEmissions - 3500).toStringAsFixed(1)} kg above average."
                                          : "Your emissions are ${(3500 - totalEmissions).toStringAsFixed(1)} kg below average.",
                                  style: AppTheme
                                      .lightTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: (isSingleSite &&
                                                totalEmissions > 350) ||
                                            (!isSingleSite &&
                                                totalEmissions > 3500)
                                        ? AppTheme.errorColor
                                        : Colors.green,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
