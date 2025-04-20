class KMeans {
  final int k;
  final int maxIter;
  List<List<double>> centroids = [];

  KMeans({required this.k, this.maxIter = 100});

  List<int> fitPredict(List<List<double>> points) {
    if (points.isEmpty) return [];
    // init: take first k points
    centroids = points.take(k).map((p) => List.of(p)).toList();

    List<int> labels = List.filled(points.length, 0);
    for (int iter = 0; iter < maxIter; iter++) {
      // assign
      bool changed = false;
      for (int i = 0; i < points.length; i++) {
        double minDist = double.infinity;
        int best = 0;
        for (int c = 0; c < k; c++) {
          final d = _distSquared(points[i], centroids[c]);
          if (d < minDist) {
            minDist = d;
            best = c;
          }
        }
        if (labels[i] != best) {
          labels[i] = best;
          changed = true;
        }
      }
      if (!changed) break;

      // update centroids
      List<List<double>> sums = List.generate(k, (_) => List.filled(points[0].length, 0));
      List<int> counts = List.filled(k, 0);
      for (int i = 0; i < points.length; i++) {
        final c = labels[i];
        for (int d = 0; d < points[i].length; d++) {
          sums[c][d] += points[i][d];
        }
        counts[c]++;
      }
      for (int c = 0; c < k; c++) {
        if (counts[c] == 0) continue;
        for (int d = 0; d < centroids[c].length; d++) {
          centroids[c][d] = sums[c][d] / counts[c];
        }
      }
    }
    return labels;
  }

  double _distSquared(List<double> a, List<double> b) {
    double s = 0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      s += diff * diff;
    }
    return s;
  }
}
