// real_time_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'ble_provider.dart';

/* ────────── colour helpers (same thresholds as main.dart) ────────── */

class _Threshold {
  const _Threshold(this.max, this.color);
  final num max;
  final Color color;
}

const _eco2Scale = [
  _Threshold(800, Colors.green),
  _Threshold(1200, Colors.yellow),
  _Threshold(2000, Colors.orange),
  _Threshold(double.infinity, Colors.red),
];
const _tvocScale = [
  _Threshold(220, Colors.green),
  _Threshold(660, Colors.yellow),
  _Threshold(2200, Colors.orange),
  _Threshold(double.infinity, Colors.red),
];
const _levelColors = <Color>[
  Colors.green,
  Colors.yellow,
  Colors.orange,
  Colors.red,
];

int _idx(List<_Threshold> scale, int v) {
  for (var i = 0; i < scale.length; ++i) {
    if (v <= scale[i].max) return i;
  }
  return scale.length - 1;
}

Color _aqColour(int eco2, int tvoc) {
  final e = _idx(_eco2Scale, eco2);
  final t = _idx(_tvocScale, tvoc);
  return _levelColors[e >= t ? e : t];
}

/* ────────── Screen ────────── */

class RealTimeMapScreen extends StatefulWidget {
  const RealTimeMapScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeMapScreen> createState() => _RealTimeMapScreenState();
}

class _RealTimeMapScreenState extends State<RealTimeMapScreen> {
  final _ctl = MapController();
  bool _centeredOnce = false;

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final pos = ble.position;

    if (pos == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final centre = LatLng(pos.latitude, pos.longitude);
    final eco2 = int.tryParse(ble.eco2) ?? 0;
    final tvoc = int.tryParse(ble.tvoc) ?? 0;
    final colour = _aqColour(eco2, tvoc);

    final circle = CircleMarker(
      point: centre,
      radius: 200, // 200 m privacy disc
      useRadiusInMeter: true,
      color: colour.withOpacity(.20),
      borderColor: colour,
      borderStrokeWidth: 1,
    );

    // centre map only first time we get a valid position
    if (!_centeredOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctl.move(centre, 15);
        _centeredOnce = true;
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Neighbourhood Air Quality')),
      body: FlutterMap(
        mapController: _ctl,
        options: MapOptions(
          initialCenter: centre,
          initialZoom: 15,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.app',
          ),
          CircleLayer(circles: [circle]),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ctl.move(centre, 15),
        tooltip: 'Re‑center',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
