// flutter/lib/features/map/map_controller.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../tracking/tracking_service.dart';
import '../tracking/territory_calculator.dart';
import '../tracking/run_mode.dart';
import '../history/run_repository.dart';

double? _bearingBetween(LatLng a, LatLng b) {
  return Geolocator.bearingBetween(
      a.latitude, a.longitude, b.latitude, b.longitude);
}

class MapController extends ChangeNotifier {
  final _trackingService = TrackingService();
  final _repository = RunRepository();

  bool get isTracking => _trackingService.isTracking;
  List<LatLng> get currentPath => _trackingService.points;

  RunMode _runMode = RunMode.territory;
  RunMode get runMode => _runMode;

  List<String> _completedTerritories = [];
  List<String> get completedTerritories => List.unmodifiable(_completedTerritories);

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  double? get currentBearing {
    final path = _trackingService.points;
    if (path.length < 2) return null;
    return _bearingBetween(path[path.length - 2], path[path.length - 1]);
  }

  // 드로잉 모드 완료 후 결과 경로 (화면 전환용)
  List<LatLng>? _completedDrawingPath;
  List<LatLng>? get completedDrawingPath => _completedDrawingPath;
  void clearDrawingPath() {
    _completedDrawingPath = null;
  }

  DateTime? _startedAt;

  Future<void> fetchCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTerritories() async {
    final runs = await _repository.fetchRuns();
    _completedTerritories =
        runs.map((r) => r.territoryGeoJson).where((g) => g.isNotEmpty).toList();
    notifyListeners();
  }

  Future<void> startRun(RunMode mode) async {
    _runMode = mode;
    _completedDrawingPath = null;
    _startedAt = DateTime.now();
    _trackingService.onPointsChanged = notifyListeners;
    _trackingService.startTracking();
    notifyListeners();
  }

  /// 완료. 드로잉 모드면 Supabase 저장 없이 경로만 반환.
  /// 땅따먹기 모드면 기존대로 저장.
  Future<void> stopRun() async {
    _trackingService.onPointsChanged = null;
    final path = _trackingService.stopTracking();
    notifyListeners();

    if (_runMode == RunMode.drawing) {
      if (path.length >= 2) {
        _completedDrawingPath = path;
        notifyListeners();
      }
      _startedAt = null;
      return;
    }

    // 땅따먹기 모드
    if (path.length < 2) {
      _startedAt = null;
      return;
    }
    final territory = TerritoryCalculator.calculate(path);
    await _repository.saveRun(
      startedAt: _startedAt!,
      endedAt: DateTime.now(),
      path: path,
      territory: territory,
    );
    await loadTerritories();
    _startedAt = null;
  }
}
