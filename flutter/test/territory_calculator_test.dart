// flutter/test/territory_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_run/features/tracking/territory_calculator.dart';

void main() {
  group('TerritoryCalculator', () {
    test('직선 경로는 버퍼 면적을 반환한다', () {
      // 서울 기준 약 100m 직선 (위도 0.001 ≈ 111m)
      final path = [
        LatLng(37.5000, 126.9000),
        LatLng(37.5009, 126.9000),
      ];
      final result = TerritoryCalculator.calculate(path);

      // 100m × 10m(좌우 5m씩) = 1000m² 근사
      expect(result.areaM2, greaterThan(500));
      expect(result.areaM2, lessThan(2000));
      expect(result.isLoop, isFalse);
    });

    test('루프 경로는 내부 면적을 포함한다', () {
      // 대략 200m × 200m 정사각형 루프
      final path = [
        LatLng(37.5000, 126.9000),
        LatLng(37.5018, 126.9000),
        LatLng(37.5018, 126.9025),
        LatLng(37.5000, 126.9025),
        LatLng(37.5000, 126.9000), // 닫힘
      ];
      final result = TerritoryCalculator.calculate(path);

      // 200m × 200m = 40000m² 근사
      expect(result.areaM2, greaterThan(30000));
      expect(result.isLoop, isTrue);
    });

    test('포인트 2개 미만이면 빈 결과를 반환한다', () {
      final result = TerritoryCalculator.calculate([LatLng(37.5, 126.9)]);
      expect(result.areaM2, equals(0));
      expect(result.geoJson, isEmpty);
    });
  });
}
