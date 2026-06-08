// flutter/lib/features/map/map_controller.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../tracking/tracking_service.dart';
import '../tracking/territory_calculator.dart';
import '../history/run_repository.dart';

class MapController extends ChangeNotifier {
  final _trackingService = TrackingService();
  final _repository = RunRepository();

  bool get isTracking => _trackingService.isTracking;
  List<LatLng> get currentPath => _trackingService.points;

  List<String> _completedTerritories = [];
  List<String> get completedTerritories => List.unmodifiable(_completedTerritories);

  DateTime? _startedAt;

  Future<void> loadTerritories() async {
    final runs = await _repository.fetchRuns();
    _completedTerritories =
        runs.map((r) => r.territoryGeoJson).where((g) => g.isNotEmpty).toList();
    notifyListeners();
  }

  Future<void> startRun() async {
    _startedAt = DateTime.now();
    _trackingService.startTracking();
    notifyListeners();
  }

  Future<void> stopRun() async {
    final path = _trackingService.stopTracking();
    notifyListeners();
    if (path.length < 2) return;

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
