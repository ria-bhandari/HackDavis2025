import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RealTimeMapScreen extends StatefulWidget {
  const RealTimeMapScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeMapScreen> createState() => _RealTimeMapScreenState();
}

class _RealTimeMapScreenState extends State<RealTimeMapScreen> {
  static final Guid _nusService = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
 static final Guid _nusTx      = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _charSub;
  Position? _currentPosition;
  int _eco2 = 0;

  GoogleMapController? _mapController;
  Marker? _marker;
  Circle? _circle;

  @override
  void initState() {
    super.initState();
    _startBleScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _charSub?.cancel();
    super.dispose();
  }

  void _startBleScan() {
    FlutterBluePlus.startScan(withServices: [_nusService], timeout: const Duration(seconds: 5));
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (results.isEmpty) return;
      final r = results.first;
      await FlutterBluePlus.stopScan();
      _device = r.device;
      await _device!.connect();
      await _discoverTx();
    });
  }

  Future<void> _discoverTx() async {
    final services = await _device!.discoverServices();
    for (final s in services) {
      if (s.uuid == _nusService) {
        for (final c in s.characteristics) {
          if (c.uuid == _nusTx) {
            await c.setNotifyValue(true);
            _charSub = c.value.listen(_handleBleData);
            return;
          }
        }
      }
    }
  }

  Future<void> _handleBleData(List<int> bytes) async {
    final line = String.fromCharCodes(bytes).trim();
    final parts = line.split(',');
    if (parts.length < 2) return;
    final eco = int.tryParse(parts[0]) ?? 0;
    // ignore tvoc for coloring but you could parse too
    setState(() => _eco2 = eco);

    // fetch location
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // update map
    _updateMap();
  }

  void _updateMap() {
    if (_mapController == null || _currentPosition == null) return;
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final pos = LatLng(lat, lng);

    // marker
    final newMarker = Marker(
      markerId: const MarkerId('sensor'),
      position: pos,
      infoWindow: InfoWindow(title: 'eCO₂: $_eco2 ppm'),
    );

    // circle color based on eco2
    Color circleColor;
    if (_eco2 < 800) {
      circleColor = Colors.green.withOpacity(0.3);
    } else if (_eco2 < 1200) {
      circleColor = Colors.orange.withOpacity(0.3);
    } else {
      circleColor = Colors.red.withOpacity(0.3);
    }

    final newCircle = Circle(
      circleId: const CircleId('area'),
      center: pos,
      radius: 50, // meters
      fillColor: circleColor,
      strokeColor: circleColor,
      strokeWidth: 1,
    );

    setState(() {
      _marker = newMarker;
      _circle = newCircle;
    });

    // animate camera
    _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real‑Time Air Quality Map'),
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 16,
              ),
              markers: _marker != null ? {_marker!} : {},
              circles: _circle != null ? {_circle!} : {},
              onMapCreated: (c) => _mapController = c,
            ),
    );
  }
}
