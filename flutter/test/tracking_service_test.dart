// flutter/test/tracking_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_run/features/tracking/tracking_service.dart';

void main() {
  group('TrackingService', () {
    late TrackingService service;

    setUp(() {
      service = TrackingService();
    });

    test('시작 전에는 포인트가 없다', () {
      expect(service.points, isEmpty);
      expect(service.isTracking, isFalse);
    });

    test('addPoint는 3m 이상 이동 시에만 포인트를 추가한다', () {
      service.startTracking();

      // 첫 번째 포인트 (항상 추가)
      service.addPoint(LatLng(37.5000, 126.9000));
      expect(service.points.length, 1);

      // 1m 이동 → 무시
      service.addPoint(LatLng(37.50001, 126.9000));
      expect(service.points.length, 1);

      // 10m 이동 → 추가
      service.addPoint(LatLng(37.5001, 126.9000));
      expect(service.points.length, 2);
    });

    test('stopTracking은 포인트 목록을 반환하고 초기화한다', () {
      service.startTracking();
      service.addPoint(LatLng(37.5000, 126.9000));
      service.addPoint(LatLng(37.5010, 126.9000));

      final points = service.stopTracking();
      expect(points.length, 2);
      expect(service.points, isEmpty);
      expect(service.isTracking, isFalse);
    });
  });
}
