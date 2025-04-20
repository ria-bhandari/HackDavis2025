// lib/real_time_map_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'ble_provider.dart';

/// Configuration
const double _simAreaRadius =
    2000; // metres around user to scatter simulated points
const double _circleRadius = 80; // metres for each circle marker

/// Colour thresholds (unchanged)
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
int _idx(List<_Threshold> s, int v) {
  for (var i = 0; i < s.length; ++i) {
    if (v <= s[i].max) return i;
  }
  return s.length - 1;
}

Color _aqColour(int eco2, int tvoc) {
  final e = _idx(_eco2Scale, eco2);
  final t = _idx(_tvocScale, tvoc);
  return _levelColors[e >= t ? e : t];
}

/// Simulated reading model
class RemoteReading {
  final double lat, lng;
  final int eco2, tvoc;
  RemoteReading({
    required this.lat,
    required this.lng,
    required this.eco2,
    required this.tvoc,
  });

  /// Scatter randomly within _simAreaRadius metres of [centre]
  factory RemoteReading.random(LatLng centre) {
    final rnd = Random();
    final r = sqrt(rnd.nextDouble()) * _simAreaRadius;
    final theta = rnd.nextDouble() * 2 * pi;
    final dx = r * cos(theta), dy = r * sin(theta);
    final dLat = dy / 111000;
    final dLng = dx / (111000 * cos(centre.latitude * pi / 180));
    return RemoteReading(
      lat: centre.latitude + dLat,
      lng: centre.longitude + dLng,
      eco2: 400 + rnd.nextInt(2200), // 400–2600 ppm
      tvoc: rnd.nextInt(3000), // 0–3000 ppb
    );
  }
}

/// Map screen with simulated users + broadcast toggle + hover tooltips
class RealTimeMapScreen extends StatefulWidget {
  const RealTimeMapScreen({Key? key}) : super(key: key);
  @override
  State<RealTimeMapScreen> createState() => _RealTimeMapScreenState();
}

class _RealTimeMapScreenState extends State<RealTimeMapScreen> {
  final _ctl = MapController();
  bool _centeredOnce = false;

  List<RemoteReading> _simulated = [];
  bool _broadcast = true;

  void _generateSimulation(LatLng centre) {
    if (_simulated.isEmpty) {
      _simulated = List.generate(12, (_) => RemoteReading.random(centre));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final pos = ble.position;
    if (pos == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final centre = LatLng(pos.latitude, pos.longitude);
    _generateSimulation(centre);

    final circles = <CircleMarker>[];
    final tooltipMarkers = <Marker>[];

    // Simulated users
    for (final r in _simulated) {
      final c = _aqColour(r.eco2, r.tvoc);
      circles.add(
        CircleMarker(
          point: LatLng(r.lat, r.lng),
          radius: _circleRadius,
          useRadiusInMeter: true,
          color: c.withOpacity(.20),
          borderColor: c,
          borderStrokeWidth: 1,
        ),
      );
      tooltipMarkers.add(
        Marker(
          point: LatLng(r.lat, r.lng),
          width: _circleRadius * 2,
          height: _circleRadius * 2,
          child: Tooltip(
            message: 'eCO₂: ${r.eco2} ppm\nTVOC: ${r.tvoc} ppb',
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    // Local user broadcast
    if (_broadcast) {
      final e = int.tryParse(ble.eco2) ?? 0;
      final t = int.tryParse(ble.tvoc) ?? 0;
      final c = _aqColour(e, t);
      circles.add(
        CircleMarker(
          point: centre,
          radius: _circleRadius,
          useRadiusInMeter: true,
          color: c.withOpacity(.25),
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ),
      );
      tooltipMarkers.add(
        Marker(
          point: centre,
          width: _circleRadius * 2,
          height: _circleRadius * 2,
          child: Tooltip(
            message: 'You\n eCO₂: $e ppm\n TVOC: $t ppb',
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    // Centre map once
    if (!_centeredOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctl.move(centre, 15);
        _centeredOnce = true;
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Simulated Air‑Quality Map')),
      body: Column(
        children: [
          // Broadcast toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Broadcast my data'),
                const Spacer(),
                Switch(
                  value: _broadcast,
                  onChanged: (v) => setState(() => _broadcast = v),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _ctl,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: 15,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: tooltipMarkers),
              ],
            ),
          ),
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
