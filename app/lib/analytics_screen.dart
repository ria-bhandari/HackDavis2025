import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'kmeans.dart';
import 'reading.dart';

class AnalyticsScreen extends StatelessWidget {
  final List<Reading> history;
  const AnalyticsScreen({super.key, required this.history});

  @override
  Widget build(BuildContext ctx) {
    if (history.isEmpty) {
      return const Center(child: Text('No data yet.'));
    }

    // Extract last N points
    final N = history.length.clamp(0, 50);
    final window = history.sublist(history.length - N);

    // Prepare chart data
    final ePoints = List.generate(
      N,
      (i) => FlSpot(
        i.toDouble(),
        double.tryParse(window[i].eco2) ?? 0.0,
      ),
    );
    final tPoints = List.generate(
      N,
      (i) => FlSpot(
        i.toDouble(),
        double.tryParse(window[i].etvoc) ?? 0.0,
      ),
    );

    // Summary metrics, now strongly typed as double
    final List<double> eco2Vals =
        window.map((r) => double.tryParse(r.eco2) ?? 0.0).toList();
    final List<double> tvocVals =
        window.map((r) => double.tryParse(r.etvoc) ?? 0.0).toList();

    final Map<String, Map<String, double>> summary = {
      'eCO₂': {
        'min': eco2Vals.reduce((a, b) => a < b ? a : b),
        'max': eco2Vals.reduce((a, b) => a > b ? a : b),
        'avg': eco2Vals.reduce((a, b) => a + b) / eco2Vals.length,
      },
      'TVOC': {
        'min': tvocVals.reduce((a, b) => a < b ? a : b),
        'max': tvocVals.reduce((a, b) => a > b ? a : b),
        'avg': tvocVals.reduce((a, b) => a + b) / tvocVals.length,
      },
    };

    // Clustering on [eco2, tvoc]
    final km = KMeans(k: 2);
    final points = window
        .map((r) => [
              double.tryParse(r.eco2) ?? 0.0,
              double.tryParse(r.etvoc) ?? 0.0,
            ])
        .toList();
    final labels = km.fitPredict(points);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Real‑time Trends', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            lineBarsData: [
              LineChartBarData(
                  spots: ePoints, isCurved: true, barWidth: 2, color: Colors.blue),
              LineChartBarData(
                  spots: tPoints, isCurved: true, barWidth: 2, color: Colors.green),
            ],
            titlesData: FlTitlesData(show: true),
            gridData: FlGridData(show: false),
          )),
        ),
        const SizedBox(height: 24),

        const Text('Summary Metrics', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: summary.entries.map((entry) {
            final metricName = entry.key;
            final m = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(metricName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Min: ${m['min']!.toStringAsFixed(1)}'),
                    Text('Max: ${m['max']!.toStringAsFixed(1)}'),
                    Text('Avg: ${m['avg']!.toStringAsFixed(1)}'),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        const Text('K‑Means Clustering', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (int i = 0; i < window.length; i++)
              Chip(
                label: Text('${window[i].eco2},${window[i].etvoc}'),
                backgroundColor:
                    labels[i] == 0 ? Colors.blue[100] : Colors.green[100],
              )
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Centroids: ${km.centroids.map((c) => '${c[0].toStringAsFixed(1)},${c[1].toStringAsFixed(1)}').join(' | ')}',
        ),
      ]),
    );
  }
}
