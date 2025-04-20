import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flip_card/flip_card.dart';
import 'package:animations/animations.dart';

import 'app_theme.dart';
import 'map_screen.dart';
import 'reading.dart';
import 'data_screen.dart';
import 'analytics_screen.dart';
import 'kmeans.dart';

void main() => runApp(const BreatheApp());

class BreatheApp extends StatelessWidget {
  const BreatheApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Breathe',
      theme: AppTheme.light(),
      home: const Shell(),
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
    // 4 pages now: Live, Map, Data, Analytics
    final pages = [
      Dashboard(
        onRead: (e,t,r) {
          setState(() {
            eco2 = e;
            tvoc = t;
            _hist.add(r);
          });
        },
        onLoc: (p) {
          setState(() => _pos = p);
        },
      ),
      MapScreen(
        lat: _pos?.latitude ?? 0,
        lng: _pos?.longitude ?? 0,
        eco2: eco2,
        etvoc: tvoc,
      ),
      DataScreen(history: _hist),
      AnalyticsScreen(history: _hist),   // ← added Analytics
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder: (child, anim, secondaryAnim) =>
            FadeThroughTransition(animation: anim, secondaryAnimation: secondaryAnim, child: child),
        child: pages[_idx],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.map_rounded),        label: 'Map'),
          NavigationDestination(icon: Icon(Icons.table_chart),        label: 'Data'),
          NavigationDestination(icon: Icon(Icons.analytics),          label: 'Analytics'),  // ← new
        ],
      ),
    );
  }
}

// ... rest of file (Dashboard, etc.) unchanged ...


/* ─────────── Dashboard page ─────────── */
class Dashboard extends StatefulWidget {
  final void Function(String,String,Reading) onRead;
  final void Function(Position) onLoc;
  const Dashboard({super.key, required this.onRead, required this.onLoc});
  @override State<Dashboard> createState() => _DashState();
}

class _DashState extends State<Dashboard> {
  BluetoothDevice? _dev;
  final nusSvc = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  final nusTx  = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  String _status='Idle', eco2='N/A', tvoc='N/A';
  Position? _pos;
  String _buf='';

  @override Widget build(BuildContext context){
    final cs=Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children:[
          /* gradient header */
          Container(
            width:double.infinity,
            padding:const EdgeInsets.all(24),
            decoration:BoxDecoration(
              gradient:LinearGradient(
                colors:[cs.primary, cs.secondary],
                begin:Alignment.topLeft,end:Alignment.bottomRight),
              borderRadius:const BorderRadius.vertical(bottom:Radius.circular(32))),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Row(
                  children:[
                    Icon(_dev!=null?Icons.bolt:Icons.bolt_outlined,color:Colors.white),
                    const SizedBox(width:8),
                    Text(_status,style:Theme.of(context).textTheme.titleLarge!.copyWith(color:Colors.white)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed:_scan,
                      style:ElevatedButton.styleFrom(backgroundColor:Colors.white54),
                      child:const Text('Connect'),
                    )
                  ]),
                const SizedBox(height:16),
                if(_pos!=null)
                  AnimatedContainer(
                    duration:const Duration(milliseconds:600),
                    padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                    decoration:BoxDecoration(
                      color:Colors.white38,borderRadius:BorderRadius.circular(20)),
                    child:Text('📍 ${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)}',
                      style:TextStyle(color:cs.onPrimary)),
                  )
              ])),
          const SizedBox(height:24),
          /* metric cards */
          _metric('eCO₂',eco2,'ppm',Icons.cloud_done,cs),
          const SizedBox(height:16),
          _metric('TVOC',tvoc,'ppb',Icons.spa,cs),
          const Spacer(),
          Text('Breathe 1.0',style:TextStyle(color:cs.outline)),
          const SizedBox(height:12)
        ]));
  }

  Widget _metric(String title,String val,String unit,IconData icon,ColorScheme cs){
    return FlipCard(
      speed:400,
      front:Card(
        child:ListTile(
          leading:Icon(icon,size:36,color:cs.primary),
          title:Text(title),
          subtitle:Text('$val $unit',style:Theme.of(context).textTheme.headlineMedium),
        )),
      back:Card(
        color:cs.primaryContainer,
        child:Center(child:Text('Latest\n$val $unit',
          textAlign:TextAlign.center,
          style:Theme.of(context).textTheme.headlineMedium!.copyWith(color:cs.onPrimaryContainer)))),
    );
  }

  /* BLE logic identical (abbrev) ---------------------------------- */
  void _scan(){
    setState(()=>_status='Scanning…');
    FlutterBluePlus.startScan(withServices:[nusSvc],timeout:const Duration(seconds:5));
    FlutterBluePlus.scanResults.listen((r)async{
      if(r.isEmpty)return;
      _dev=r.first.device;
      await FlutterBluePlus.stopScan();
      await _dev!.connect();
      setState(()=>_status='Connected');
      _discover();
      _gps();
    });
  }
  Future<void> _discover()async{
    for(final s in await _dev!.discoverServices()){
      if(s.uuid==nusSvc){
        for(final c in s.characteristics){
          if(c.uuid==nusTx){
            await c.setNotifyValue(true);
            c.value.listen(_handle);
          }
        }
      }
    }
  }
  void _handle(List<int> b){
    _buf+=String.fromCharCodes(b);
    if(!_buf.contains('\n'))return;
    final parts=_buf.split('\n'); _buf=parts.removeLast();
    for(final l in parts){
      final p=l.split(',');
      if(p.length==2){
        setState((){eco2=p[0]; tvoc=p[1];});
        final r=Reading(
          eco2:p[0],etvoc:p[1],time:DateTime.now(),
          lat:_pos?.latitude,lng:_pos?.longitude);
        widget.onRead(p[0],p[1],r);
      }
    }
  }
  Future<void> _gps()async{
    _pos=await Geolocator.getCurrentPosition();
    widget.onLoc(_pos!);
  }
}
