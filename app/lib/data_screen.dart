import 'package:flutter/material.dart';
import 'reading.dart';

class DataScreen extends StatelessWidget {
  final List<Reading> history;
  const DataScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor History')),
      body: ListView.separated(
        itemCount: history.length,
        reverse: true,                 // newest first
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (_, i) {
          final r = history[history.length - 1 - i];   // reverse order
          return ListTile(
            title: Text('eCO₂: ${r.eco2} ppm • TVOC: ${r.etvoc} ppb'),
            subtitle: Text(
              '${r.time.toLocal()}  '
              '${r.lat != null ? "(${r.lat!.toStringAsFixed(4)}, ${r.lng!.toStringAsFixed(4)})" : ""}',
            ),
          );
        },
      ),
    );
  }
}
