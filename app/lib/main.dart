import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flip_card/flip_card.dart';
import 'package:animations/animations.dart';
import 'package:geolocator/geolocator.dart';

import 'app_theme.dart';
import 'welcome_screen.dart';
import 'auth_screen.dart';
import 'ble_provider.dart';
import 'reading.dart';
import 'data_screen.dart';
import 'analytics_screen.dart';
import 'real_time_map_screen.dart';

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

Color _scaleColor(List<_Threshold> scale, int value) =>
    scale.firstWhere((t) => value <= t.max).color;
Color colourForEco2(int eco2) => _scaleColor(_eco2Scale, eco2);
Color colourForTvoc(int tvoc) => _scaleColor(_tvocScale, tvoc);
Color _contrastOn(Color bg) =>
    bg.computeLuminance() > .5 ? Colors.black : Colors.white;

// ──────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BleProvider())],
      child: const BreatheApp(),
    ),
  );
}

class BreatheApp extends StatelessWidget {
  const BreatheApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breathe',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == null) {
            return const WelcomeScreen();
          }
          return const Shell();
        },
      ),
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
  final _hist = <Reading>[];

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    // record history when readings update
    if (ble.eco2 != 'N/A' && ble.tvoc != 'N/A') {
      _hist.add(Reading(
        eco2: ble.eco2,
        etvoc: ble.tvoc,
        time: DateTime.now(),
        lat: ble.position?.latitude,
        lng: ble.position?.longitude,
      ));
    }

    final pages = [
      const Dashboard(),
      const RealTimeMapScreen(),
      DataScreen(history: _hist),
      AnalyticsScreen(history: _hist),
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder: (c, a1, a2) =>
            FadeThroughTransition(animation: a1, secondaryAnimation: a2, child: c),
        child: pages[_idx],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.table_chart), label: 'Data'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }
}

/* ─────────── Dashboard page ─────────── */
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashState();
}

class _DashState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleProvider>();
    final cs = Theme.of(context).colorScheme;
    final pos = ble.position;

    return SafeArea(
      child: Column(
        children: [
          // Header with Connect button
          Container(
            color: cs.primary,
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.read<BleProvider>().scanAndConnect(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ble.status,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _metric(context, 'eCO₂', ble.eco2, 'ppm', Icons.cloud_done, cs),
          const SizedBox(height: 16),
          _metric(context, 'TVOC', ble.tvoc, 'ppb', Icons.spa, cs),
          const Spacer(),

          if (pos != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '📍 ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
              ),
            ),

          const SizedBox(height: 12),
          Text('Breathe 1.0', style: TextStyle(color: cs.outline)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String title,
    String val,
    String unit,
    IconData icon,
    ColorScheme cs,
  ) {
    final int parsed = int.tryParse(val) ?? 0;
    final bg = title == 'eCO₂'
        ? colourForEco2(parsed)
        : colourForTvoc(parsed);
    final fg = _contrastOn(bg);

    return FlipCard(
      speed: 400,
      front: Card(
        elevation: 4,
        child: ListTile(
          leading: Icon(icon, size: 36, color: bg),
          title: Text(title),
          subtitle: Text('$val $unit',
              style: Theme.of(context).textTheme.headlineMedium),
        ),
      ),
      back: Card(
        color: bg,
        elevation: 4,
        child: Center(
          child: Text(
            'Latest\n$val $unit',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}
