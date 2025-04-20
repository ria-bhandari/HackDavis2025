class Reading {
  final String eco2;
  final String etvoc;
  final DateTime time;
  final double? lat;
  final double? lng;
  Reading({
    required this.eco2,
    required this.etvoc,
    required this.time,
    this.lat,
    this.lng,
  });
}
