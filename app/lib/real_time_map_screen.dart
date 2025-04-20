// real_time_map_screen.dart  (privacy‑enhanced)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/* ────────── AQI helpers (unchanged) ────────── */

@immutable
class Threshold {
  const Threshold(this.max, this.color);
  final num max;
  final Color color;
}

const _eco2Scale = [
  Threshold(800, Colors.green),
  Threshold(1200, Colors.yellow),
  Threshold(2000, Colors.orange),
  Threshold(double.infinity, Colors.red),
];
const _tvocScale = [
  Threshold(220, Colors.green),
  Threshold(660, Colors.yellow),
  Threshold(2200, Colors.orange),
  Threshold(double.infinity, Colors.red),
];
const _levelColors = <Color>[
  Colors.green,
  Colors.yellow,
  Colors.orange,
  Colors.red,
];

int _severityIdx(List<Threshold> scale, int v) {
  for (var i = 0; i < scale.length; ++i) {
    if (v <= scale[i].max) return i;
  }
  return scale.length - 1;
}

Color _scoreColor(int eco2, int tvoc) {
  final idxEco = _severityIdx(_eco2Scale, eco2);
  final idxTvoc = _severityIdx(_tvocScale, tvoc);
  return _levelColors[idxEco >= idxTvoc ? idxEco : idxTvoc];
}

/* ────────── Map Screen ────────── */

class RealTimeMapScreen extends StatefulWidget {
  const RealTimeMapScreen({Key? key}) : super(key: key);
  @override
  State<RealTimeMapScreen> createState() => _RealTimeMapScreenState();
}

class _RealTimeMapScreenState extends State<RealTimeMapScreen> {
  /* BLE UUIDs */
  static final _svc = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final _tx = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  BluetoothDevice? _dev;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _charSub;

  /* Sensor values + last known pos */
  Position? _pos;
  int _eco2 = 0, _tvoc = 0;

  /* Map */
  final _mapCtl = MapController();
  List<CircleMarker> _circles = [];
  bool _centeredOnce = false;

  /* Location stream */
  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    _requestPermAndStart();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _charSub?.cancel();
    _posStream?.cancel();
    super.dispose();
  }

  /* ── permissions + streams ── */

  Future<void> _requestPermAndStart() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
      _startPositionStream();
      _startBleScan();
    }
  }

  void _startPositionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    );
    _posStream = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) {
      _pos = pos;
      _updateCircle(); // keep disc on top of new pos
    });
  }

  /* ── BLE handling ── */

  void _startBleScan() {
    FlutterBluePlus.startScan(
      withServices: [_svc],
      timeout: const Duration(seconds: 5),
    );
    _scanSub = FlutterBluePlus.scanResults.listen((r) async {
      if (r.isEmpty) return;
      await FlutterBluePlus.stopScan();
      _dev = r.first.device;
      await _dev!.connect();
      for (final s in await _dev!.discoverServices()) {
        if (s.uuid != _svc) continue;
        for (final c in s.characteristics) {
          if (c.uuid == _tx) {
            await c.setNotifyValue(true);
            _charSub = c.value.listen(_handleBle);
            return;
          }
        }
      }
    });
  }

  void _handleBle(List<int> bytes) {
    final s = String.fromCharCodes(bytes).trim();
    final p = s.split(',');
    if (p.length != 2) return;
    setState(() {
      _eco2 = int.tryParse(p[0]) ?? 0;
      _tvoc = int.tryParse(p[1]) ?? 0;
    });
    _updateCircle();
  }

  /* ── map update ── */

  void _updateCircle() {
    if (_pos == null) return;

    final centre = LatLng(_pos!.latitude, _pos!.longitude);
    final colour = _scoreColor(_eco2, _tvoc);

    _circles = [
      CircleMarker(
        point: centre,
        color: colour.withOpacity(.20),
        borderColor: colour,
        borderStrokeWidth: 1,
        radius: 200, // 200 m radius ≈ 4 × previous
        useRadiusInMeter: true,
      ),
    ];

    /* recentre cam only first time */
    if (!_centeredOnce) {
      _mapCtl.move(centre, 15); // one zoom level out for larger disc
      _centeredOnce = true;
    }
    setState(() {}); // refresh layer
  }

  /* ── UI ── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neighbourhood Air Quality')),
      body:
          _pos == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                mapController: _mapCtl,
                options: MapOptions(
                  initialCenter: LatLng(_pos!.latitude, _pos!.longitude),
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
                  CircleLayer(circles: _circles),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_pos != null) {
            _mapCtl.move(LatLng(_pos!.latitude, _pos!.longitude), 15);
          }
        },
        child: const Icon(Icons.my_location),
        tooltip: 'Re‑center',
      ),
    );
  }
}
