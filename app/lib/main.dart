import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flip_card/flip_card.dart';
import 'package:animations/animations.dart';

import 'welcome_screen.dart';
import 'real_time_map_screen.dart';
import 'app_theme.dart';
import 'reading.dart';
import 'data_screen.dart';
import 'analytics_screen.dart';
import 'kmeans.dart';

// ───────────────────── Thresholds for air‑quality colours ─────────────────────
@immutable
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

Color _scaleColor(List<_Threshold> scale, int value) {
  return scale.firstWhere((t) => value <= t.max).color;
}

Color colourForEco2(int eco2) => _scaleColor(_eco2Scale, eco2);
Color colourForTvoc(int tvoc) => _scaleColor(_tvocScale, tvoc);

Color _contrastOn(Color bg) =>
    bg.computeLuminance() > .5 ? Colors.black : Colors.white;

// ──────────────────────────────────────────────────────────────────────────────

void main() => runApp(const BreatheApp());

class BreatheApp extends StatelessWidget {
  const BreatheApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Breathe',
      theme: AppTheme.light(),
      home: const WelcomeScreen(),
    );
  }
}

/* ─────────── Shell with bottom nav ─────────── */
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _idx = 0;
  Position? _pos;
  final _hist = <Reading>[];
  String eco2 = 'N/A', tvoc = 'N/A';

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        onRead: (e, t, r) {
          setState(() {
            eco2 = e;
            tvoc = t;
            _hist.add(r);
          });
        },
        onLoc: (p) => setState(() => _pos = p),
      ),
      const RealTimeMapScreen(),
      DataScreen(history: _hist),
      AnalyticsScreen(history: _hist),
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder:
            (child, anim, secondaryAnim) => FadeThroughTransition(
              animation: anim,
              secondaryAnimation: secondaryAnim,
              child: child,
            ),
        child: pages[_idx],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Live',
          ),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.table_chart), label: 'Data'),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}

/* ─────────── Dashboard page ─────────── */
class Dashboard extends StatefulWidget {
  final void Function(String, String, Reading) onRead;
  final void Function(Position) onLoc;
  const Dashboard({super.key, required this.onRead, required this.onLoc});
  @override
  State<Dashboard> createState() => _DashState();
}

class _DashState extends State<Dashboard> {
  BluetoothDevice? _dev;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  final nusSvc = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  final nusTx = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  String _status = 'Idle', eco2 = 'N/A', tvoc = 'N/A';
  Position? _pos;
  String _buf = '';

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  /* ---------- BLE one‑shot connect ---------- */
  void _scanAndConnect() {
    if (_dev != null) return;
    setState(() => _status = 'Scanning…');

    FlutterBluePlus.startScan(
      withServices: [nusSvc],
      timeout: const Duration(seconds: 5),
    );

    FlutterBluePlus.scanResults.listen((results) async {
      if (_dev != null || results.isEmpty) return;
      final match = results.first;
      _dev = match.device;
      await FlutterBluePlus.stopScan();
      await _dev!.connect();

      _stateSub = _dev!.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          setState(() => _status = 'Disconnected');
        }
      });

      setState(() => _status = 'Connected to ${_dev!.name}');
      _discoverTx();
      _updateLocation();
    });
  }

  Future<void> _discoverTx() async {
    for (final s in await _dev!.discoverServices()) {
      if (s.uuid == nusSvc) {
        for (final c in s.characteristics) {
          if (c.uuid == nusTx) {
            await c.setNotifyValue(true);
            c.value.listen(_handle);
            return;
          }
        }
      }
    }
    setState(() => _status = 'TX char not found');
  }

  void _handle(List<int> b) {
    _buf += String.fromCharCodes(b);
    if (!_buf.contains('\n')) return;
    final lines = _buf.split('\n');
    _buf = lines.removeLast();

    for (final line in lines) {
      final p = line.split(',');
      if (p.length == 2) {
        setState(() {
          eco2 = p[0];
          tvoc = p[1];
        });
        widget.onRead(
          p[0],
          p[1],
          Reading(
            eco2: p[0],
            etvoc: p[1],
            time: DateTime.now(),
            lat: _pos?.latitude,
            lng: _pos?.longitude,
          ),
        );
        _updateLocation();
      }
    }
  }

  Future<void> _updateLocation() async {
    _pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    widget.onLoc(_pos!);
    setState(() {});
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _dev != null
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _dev == null ? _scanAndConnect : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: cs.primary,
                      ),
                      child: const Text('Connect'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_pos != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '📍 ${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)}',
                      style: TextStyle(color: cs.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _metric('eCO₂', eco2, 'ppm', Icons.cloud_done, cs),
          const SizedBox(height: 16),
          _metric('TVOC', tvoc, 'ppb', Icons.spa, cs),
          const Spacer(),
          Text('Breathe 1.0', style: TextStyle(color: cs.outline)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _metric(
    String title,
    String val,
    String unit,
    IconData icon,
    ColorScheme cs,
  ) {
    Color colour = cs.primary; // default when N/A
    if (val != 'N/A') {
      final v = int.tryParse(val) ?? 0;
      colour = title.startsWith('eCO') ? colourForEco2(v) : colourForTvoc(v);
    }
    final onColour = _contrastOn(colour);

    return FlipCard(
      speed: 400,
      front: Card(
        child: ListTile(
          leading: Icon(icon, size: 36, color: colour),
          title: Text(title),
          subtitle: Text(
            '$val $unit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
      back: Card(
        color: colour,
        child: Center(
          child: Text(
            'Latest\n$val $unit',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium!.copyWith(color: onColour),
          ),
        ),
      ),
    );
  }
}
