// lib/ble_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

class BleProvider extends ChangeNotifier {
  /* Public state */
  String status = 'Idle';
  String eco2 = 'N/A', tvoc = 'N/A';
  Position? position;

  /* BLE internals */
  BluetoothDevice? _dev;
  StreamSubscription<List<int>>? _charSub;
  final _svc = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  final _tx = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
  String _buf = '';

  /// Start scan & connect
  Future<void> scanAndConnect() async {
    status = 'Scanning…';
    notifyListeners();
    await FlutterBluePlus.startScan(
      withServices: [_svc],
      timeout: const Duration(seconds: 5),
    );
    FlutterBluePlus.scanResults.listen((results) async {
      if (results.isEmpty) return;
      _dev = results.first.device;
      await FlutterBluePlus.stopScan();
      await _dev!.connect();
      status = 'Connected to ${_dev!.name}';
      notifyListeners();

      // subscribe to notifications
      for (final s in await _dev!.discoverServices()) {
        if (s.uuid != _svc) continue;
        for (final c in s.characteristics) {
          if (c.uuid == _tx) {
            await c.setNotifyValue(true);
            _charSub = c.value.listen(_onBleData);
            break;
          }
        }
      }
      // immediately fetch position
      _updatePosition();
    });
  }

  /// Parse incoming BLE lines
  void _onBleData(List<int> data) {
    _buf += String.fromCharCodes(data);
    if (!_buf.contains('\n')) return;
    final lines = _buf.split('\n');
    _buf = lines.removeLast();
    for (final l in lines) {
      final p = l.split(',');
      if (p.length != 2) continue;
      eco2 = p[0];
      tvoc = p[1];
      notifyListeners();
    }
  }

  /// One‑shot high‑accuracy GPS
  Future<void> _updatePosition() async {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _charSub?.cancel();
    _dev?.disconnect();
    super.dispose();
  }
}
