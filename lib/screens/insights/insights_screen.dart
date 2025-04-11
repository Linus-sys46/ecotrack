import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';

class InsightsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> emissions;
  final String status;

  const InsightsScreen(
      {super.key, required this.emissions, required this.status});

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
        DateTime date = DateTime.parse(entry['created_at']);
        String monthKey =
            "${date.year}-${date.month.toString().padLeft(2, '0')}";
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) +
            (entry['co2e_monthly']?.toDouble() ?? 0.0);
      }
    }
    return monthlyData;
  }

  // Group emissions by primary energy source for breakdown
  Map<String, double> getEmissionsBySource() {
    Map<String, double> sourceData = {};
    for (var entry in emissions) {
      String source = entry['primary_energy'] ?? 'Unknown';
      sourceData[source] = (sourceData[source] ?? 0.0) +
          (entry['co2e_monthly']?.toDouble() ?? 0.0);
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
    final monthlyValues =
        sortedMonths.map((month) => monthlyEmissions[month]!).toList();

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
                "Insights",
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
                                            : status == 'Error' ||
                                                    status == 'Loading...'
                                                ? Colors.grey
                                                : Colors.red,
                                  ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Emissions Trend Over Time",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          monthlyEmissions.isEmpty
                              ? const Center(
                                  child: Text("No trend data available."))
                              : SizedBox(
                                  height: 200,
                                  child: LineChart(
                                    LineChartData(
                                      gridData: const FlGridData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) =>
                                                Text(
                                              value.toInt().toString(),
                                              style: AppTheme.lightTheme
                                                  .textTheme.bodySmall,
                                            ),
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              int index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      sortedMonths.length) {
                                                return const SizedBox.shrink();
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8.0),
                                                child: Text(
                                                  sortedMonths[index].split(
                                                      '-')[1], // Show month
                                                  style: AppTheme.lightTheme
                                                      .textTheme.bodySmall,
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
                                              .map((e) {
                                            return FlSpot(
                                                e.key.toDouble(), e.value);
                                          }).toList(),
                                          isCurved: true,
                                          color: AppTheme.primaryColor,
                                          barWidth: 3,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: AppTheme.primaryColor
                                                .withAlpha(
                                                    51), // 0.2 opacity -> 51/255
                                          ),
                                        ),
                                      ],
                                      minY: 0,
                                      maxY: (monthlyValues.isNotEmpty
                                              ? monthlyValues.reduce(
                                                      (a, b) => a > b ? a : b) *
                                                  1.2
                                              : 1000)
                                          .toDouble(),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emissions Breakdown by Source (Pie Chart)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Emissions by Source",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          emissionsBySource.isEmpty
                              ? const Center(
                                  child: Text("No source data available."))
                              : SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: emissionsBySource.entries
                                          .map((entry) {
                                        int index = emissionsBySource.keys
                                            .toList()
                                            .indexOf(entry.key);
                                        return PieChartSectionData(
                                          color: AppTheme.chartColors[index %
                                              AppTheme.chartColors.length],
                                          value: entry.value,
                                          title:
                                              "${(entry.value / totalEmissions * 100).toStringAsFixed(1)}%",
                                          radius: 80,
                                          titleStyle: AppTheme
                                              .lightTheme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }).toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          // Legend for Pie Chart
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: emissionsBySource.keys.map((source) {
                              int index = emissionsBySource.keys
                                  .toList()
                                  .indexOf(source);
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
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comparison with Average (Static for now)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Comparison with Average",
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
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
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyLarge,
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
                                  "Average User: 1200 kg CO2e", // Static value for now
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            totalEmissions > 1200
                                ? "Your emissions are ${(totalEmissions - 1200).toStringAsFixed(1)} kg above average."
                                : "Your emissions are ${(1200 - totalEmissions).toStringAsFixed(1)} kg below average.",
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: totalEmissions > 1200
                                  ? AppTheme.errorColor
                                  : Colors.green,
                            ),
                          ),
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
