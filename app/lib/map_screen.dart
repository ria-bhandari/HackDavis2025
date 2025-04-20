import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final double lat, lng;
  final String eco2, etvoc;
  const MapScreen(
      {super.key,
      required this.lat,
      required this.lng,
      required this.eco2,
      required this.etvoc});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _mapReady = !kIsWeb; // native is always ready

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
  // give JS a tick to attach the map div
  WidgetsBinding.instance.addPostFrameCallback((_) {
    setState(() {
      _mapReady = context.findRenderObject() != null;
    });
  });
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Air Quality Map')),
      body: _mapReady
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.lat, widget.lng),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('here'),
                  position: LatLng(widget.lat, widget.lng),
                  infoWindow: InfoWindow(
                      title: 'eCO₂ ${widget.eco2} ppm',
                      snippet: 'TVOC ${widget.etvoc} ppb'),
                )
              },
            )
          : Center(
              child: Text(
                'Google Maps SDK not loaded.\n'
                'Check API key & script tag.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.red),
              ),
            ),
    );
  }
}
