import 'dart:math';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371; // Earth's radius in km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}

String formatDistance(double distance) {
  if (distance < 1) {
    return '${(distance * 1000).round()} m';
  }
  return '${distance.toStringAsFixed(1)} km';
}

double calculateJaccardSimilarity(List<String> set1, List<String> set2) {
  if (set1.isEmpty && set2.isEmpty) return 0;
  final intersection = set1.where((item) => set2.contains(item)).length;
  final union = set1.toSet().union(set2.toSet()).length;
  return intersection / union;
}