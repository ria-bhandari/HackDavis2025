import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

class BleProvider extends ChangeNotifier {
  // Nordic UART Service UUIDs
  final Guid nusService = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  final Guid nusTxChar  = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  BluetoothDevice? device;
  BluetoothConnectionState connectionState = BluetoothConnectionState.disconnected;
  String status = 'Idle';
  String eco2 = 'N/A', tvoc = 'N/A';
  Position? position;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  StreamSubscription<List<int>>? _charSub;
  String _buffer = '';

  /// Start a one‑shot scan → connect → subscribe flow.
  Future<void> scanAndConnect() async {
    if (device != null) return; // already connected

    // On Android, request location permission (needed for BLE scanning)
    if (!kIsWeb && Platform.isAndroid) {
      await Geolocator.requestPermission();
    }

    status = 'Scanning…';
    notifyListeners();

    // 1️⃣ Begin scanning, filtered by your NUS service
    FlutterBluePlus.startScan(
      withServices: [nusService],
      timeout: const Duration(seconds: 5),
    );

    // 2️⃣ Listen for scan results
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (device != null) return;      // already connected in flight
      if (results.isEmpty) return;     // no peripherals yet

      // take the first one
      final match = results.first;
      device = match.device;

      // stop scanning
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      status = 'Connecting to ${device!.name}…';
      notifyListeners();

      // listen to connection changes
      _stateSub = device!.state.listen((s) {
        connectionState = s;
        status = s == BluetoothConnectionState.connected
            ? 'Connected to ${device!.name}'
            : 'Disconnected';
        notifyListeners();

        if (s == BluetoothConnectionState.connected) {
          _discoverTx();
          _updateLocation();
        }
      });

      // actually connect
      try {
        await device!.connect(autoConnect: false);
      } catch (_) {
        // might already be connected
      }
    });

    // 3️⃣ Fallback: after 5s, if still no device, cancel & report
    Future.delayed(const Duration(seconds: 5), () async {
      if (device == null) {
        await FlutterBluePlus.stopScan();
        await _scanSub?.cancel();
        status = 'No device found';
        notifyListeners();
      }
    });
  }

  Future<void> _discoverTx() async {
    final services = await device!.discoverServices();
    for (final svc in services) {
      if (svc.uuid == nusService) {
        for (final c in svc.characteristics) {
          if (c.uuid == nusTxChar) {
            await c.setNotifyValue(true);
            _charSub = c.value.listen(_onData);
            return;
          }
        }
      }
    }
    status = 'TX char not found';
    notifyListeners();
  }

  void _onData(List<int> bytes) {
    _buffer += String.fromCharCodes(bytes);
    if (!_buffer.contains('\n')) return;

    final lines = _buffer.split('\n');
    _buffer = lines.removeLast();

    for (final line in lines) {
      final parts = line.split(',');
      if (parts.length == 2) {
        eco2 = parts[0];
        tvoc = parts[1];
        notifyListeners();
        _updateLocation();
      }
    }
  }

  Future<void> _updateLocation() async {
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _stateSub?.cancel();
    _charSub?.cancel();
    super.dispose();
  }
}
