import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';

// EmissionCalculator class (unchanged)
class EmissionCalculator {
  static const double lpgFactor = 3.0; // kg CO2e/kg LPG
  static const double electricityFactor = 0.4; // kg CO2e/kWh
  static const double charcoalFactor = 1.5;
  static const double dieselFactor = 2.68;
  static const double poultryMethaneFactor = 0.02;
  static const double poultryN2OFactor = 0.01;

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
        return 0.0; // Default for 'Other' or null
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

  // Calculate total emissions
  double getTotalEmissions() {
    return emissions.fold(
        0.0, (sum, item) => sum + (item['co2e_monthly']?.toDouble() ?? 0.0));
  }

  // Group emissions by month for trend analysis
  Map<String, double> getMonthlyEmissions() {
    Map<String, double> monthlyData = {};
    for (var entry in emissions) {
      if (entry['created_at'] != null) {
        try {
          DateTime date = DateTime.parse(entry['created_at']);
          String monthKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}";
          monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) +
              (entry['co2e_monthly']?.toDouble() ?? 0.0);
        } catch (e) {
          print(
              "Error parsing date for entry: ${entry['created_at']}, error: $e");
          continue;
        }
      }
    }
    return monthlyData;
  }

  // Group emissions by both primary and secondary sources
  Map<String, double> getEmissionsBySource() {
    Map<String, double> sourceData = {};
    final calculator = EmissionCalculator();

    for (var entry in emissions) {
      final String primarySource = entry['primary_source'] ?? 'Unknown';
      final double primaryAmount = (entry['primary_amount'] ?? 0.0).toDouble();
      final String? secondarySource = entry['secondary_source'];
      final double secondaryAmount =
          (entry['secondary_amount'] ?? 0.0).toDouble();
      final double hours = (entry['hours'] ?? 0.0).toDouble();
      final double totalCo2e = entry['co2e_monthly']?.toDouble() ?? 0.0;

      // Calculate CO2e contributions for primary and secondary sources (before hours multiplier)
      final double primaryCo2ePerHour =
          calculator.calculateEmissionForSource(primarySource, primaryAmount);
      final double secondaryCo2ePerHour = secondarySource != null
          ? calculator.calculateEmissionForSource(
              secondarySource, secondaryAmount)
          : 0.0;
      final double totalCo2ePerHour = primaryCo2ePerHour + secondaryCo2ePerHour;

      // Avoid division by zero
      if (totalCo2ePerHour == 0 || hours == 0) continue;

      // Calculate the proportion of totalCo2e attributed to each source
      final double primaryProportion = primaryCo2ePerHour / totalCo2ePerHour;
      final double secondaryProportion =
          secondaryCo2ePerHour / totalCo2ePerHour;

      final double primaryCo2e = totalCo2e * primaryProportion;
      final double secondaryCo2e = totalCo2e * secondaryProportion;

      // Add primary source contribution
      sourceData[primarySource] =
          (sourceData[primarySource] ?? 0.0) + primaryCo2e;

      // Add secondary source contribution if it exists
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

    // Sort monthly emissions for the line chart
    final sortedMonths = monthlyEmissions.keys.toList()..sort();
    final monthlyValues = sortedMonths.isNotEmpty
        ? sortedMonths
            .map((month) => monthlyEmissions[month]!.toDouble())
            .toList()
        : <double>[];

    // Calculate the interval for x-axis labels to prevent overlap
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
                  // Total Emissions and Status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Overview",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                                    color: status == 'Good'
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

                  // Emissions Trend Over Time (Line Chart)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Emissions Trend Over Time",
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        monthlyEmissions.isEmpty
                            ? const Center(
                                child: Text("No trend data available."),
                              )
                            : SizedBox(
                                height: 200,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 200,
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) =>
                                              Text(
                                            value.toStringAsFixed(0),
                                            style: AppTheme
                                                .lightTheme.textTheme.bodySmall,
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
                                                index >= sortedMonths.length) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Text(
                                                sortedMonths[index],
                                                style: AppTheme.lightTheme
                                                    .textTheme.bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(
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
                                        dotData: const FlDotData(show: true),
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
                                        : 1000,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emissions Breakdown by Source (Pie Chart)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Emissions by Source",
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 24),
                        emissionsBySource.isEmpty
                            ? const Center(
                                child: Text("No source data available."))
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: emissionsBySource.entries
                                          .map((entry) {
                                        final index = emissionsBySource.keys
                                            .toList()
                                            .indexOf(entry.key);
                                        return PieChartSectionData(
                                          color: AppTheme.chartColors[index %
                                              AppTheme.chartColors.length],
                                          value: entry.value,
                                          title:
                                              "${(entry.value / totalEmissions * 100).toStringAsFixed(1)}%",
                                          radius: 90,
                                          titleStyle: AppTheme
                                              .lightTheme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          titlePositionPercentageOffset: 0.6,
                                        );
                                      }).toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 12),
                        // Legend for Pie Chart
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: emissionsBySource.keys.map((source) {
                            final index =
                                emissionsBySource.keys.toList().indexOf(source);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  color: AppTheme.chartColors[
                                      index % AppTheme.chartColors.length],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  source,
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comparison with Average
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Comparison with Average",
                          style: AppTheme.lightTheme.textTheme.titleLarge
                              ?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.compare_arrows,
                                color: AppTheme.accentColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Your Emissions: ${totalEmissions.toStringAsFixed(1)} kg CO2e",
                                style: AppTheme.lightTheme.textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.compare_arrows,
                                color: AppTheme.secondaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Average User: 5000 kg CO2e",
                                style: AppTheme.lightTheme.textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          totalEmissions > 5000
                              ? "Your emissions are ${(totalEmissions - 5000).toStringAsFixed(1)} kg above average."
                              : "Your emissions are ${(5000 - totalEmissions).toStringAsFixed(1)} kg below average.",
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: totalEmissions > 5000
                                ? AppTheme.errorColor
                                : Colors.green,
                          ),
                          softWrap: true,
                        ),
                      ],
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
