// flutter/lib/features/tracking/territory_calculator.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';

class TerritoryResult {
  final double areaM2;
  final bool isLoop;
  final String geoJson;

  const TerritoryResult({
    required this.areaM2,
    required this.isLoop,
    required this.geoJson,
  });

  static const empty = TerritoryResult(areaM2: 0, isLoop: false, geoJson: '');
}

class TerritoryCalculator {
  static const double _bufferDeg = 5.0 / 111320.0; // 5m → degrees

  static TerritoryResult calculate(List<LatLng> path) {
    if (path.length < 2) return TerritoryResult.empty;

    final isLoop = _isLoop(path);

    if (isLoop) {
      final coords = _toCoords(path);
      final area = _polygonAreaM2(path);
      final geoJson = _makePolygonGeoJson(coords);
      return TerritoryResult(areaM2: area, isLoop: true, geoJson: geoJson);
    } else {
      final length = _pathLengthM(path);
      final area = length * 10.0; // 좌우 5m씩 = 너비 10m
      final bufferedCoords = _buildBufferPolygon(path);
      final geoJson = _makePolygonGeoJson(bufferedCoords);
      return TerritoryResult(areaM2: area, isLoop: false, geoJson: geoJson);
    }
  }

  // 시작점과 마지막 점이 20m 이내면 루프
  static bool _isLoop(List<LatLng> path) {
    if (path.length < 3) return false;
    final dist = const Distance().as(LengthUnit.Meter, path.first, path.last);
    return dist <= 20.0;
  }

  // 경로 전체 길이 (m)
  static double _pathLengthM(List<LatLng> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += const Distance().as(LengthUnit.Meter, path[i], path[i + 1]);
    }
    return total;
  }

  // 폴리곤 면적 (Shoelace, 구면 근사)
  static double _polygonAreaM2(List<LatLng> path) {
    const metersPerDegLat = 111320.0;
    double area = 0;
    final n = path.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = path[i].longitude *
          metersPerDegLat *
          cos(path[i].latitude * pi / 180);
      final yi = path[i].latitude * metersPerDegLat;
      final xj = path[j].longitude *
          metersPerDegLat *
          cos(path[j].latitude * pi / 180);
      final yj = path[j].latitude * metersPerDegLat;
      area += xi * yj - xj * yi;
    }
    return area.abs() / 2.0;
  }

  // 버퍼 폴리곤: 경로 좌우로 _bufferDeg 확장
  static List<List<double>> _buildBufferPolygon(List<LatLng> path) {
    final left = <List<double>>[];
    final right = <List<double>>[];

    for (int i = 0; i < path.length - 1; i++) {
      final dx = path[i + 1].longitude - path[i].longitude;
      final dy = path[i + 1].latitude - path[i].latitude;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len * _bufferDeg;
      final ny = dx / len * _bufferDeg;
      left.add([path[i].longitude + nx, path[i].latitude + ny]);
      right.add([path[i].longitude - nx, path[i].latitude - ny]);
    }

    final last = path.last;
    final secondLast = path[path.length - 2];
    final dx = last.longitude - secondLast.longitude;
    final dy = last.latitude - secondLast.latitude;
    final len = sqrt(dx * dx + dy * dy);
    if (len > 0) {
      final nx = -dy / len * _bufferDeg;
      final ny = dx / len * _bufferDeg;
      left.add([last.longitude + nx, last.latitude + ny]);
      right.add([last.longitude - nx, last.latitude - ny]);
    }

    return [...left, ...right.reversed, left.first];
  }

  static List<List<double>> _toCoords(List<LatLng> path) =>
      path.map((p) => [p.longitude, p.latitude]).toList();

  static String _makePolygonGeoJson(List<List<double>> coords) {
    final coordStr = coords.map((c) => '[${c[0]},${c[1]}]').join(',');
    return '{"type":"Polygon","coordinates":[[$coordStr]]}';
  }
}
