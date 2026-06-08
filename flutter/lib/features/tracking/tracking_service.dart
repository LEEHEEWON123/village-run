// flutter/lib/features/tracking/tracking_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';

class TrackingService {
  final List<LatLng> _points = [];
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  List<LatLng> get points => List.unmodifiable(_points);
  bool get isTracking => _isTracking;

  /// Starts tracking. Sets isTracking = true immediately.
  /// Starts GPS stream on real devices (permission request is async).
  void startTracking() {
    _positionSubscription?.cancel();  // cancel any existing GPS stream
    _positionSubscription = null;     // clear the reference
    _points.clear();
    _isTracking = true;
    _startGpsStream(); // fire-and-forget, non-blocking
  }

  Future<void> _startGpsStream() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // GPS unavailable, manual addPoint still works
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen((pos) {
        addPoint(LatLng(pos.latitude, pos.longitude));
      });
    } catch (_) {
      // GPS not available in test environment — silent fallback
    }
  }

  /// Adds a GPS point. Ignores if not tracking or if moved < minMoveMeters.
  void addPoint(LatLng point) {
    if (!_isTracking) return;

    if (_points.isEmpty) {
      _points.add(point);
      return;
    }

    final dist = const Distance().as(LengthUnit.Meter, _points.last, point);
    if (dist >= AppConstants.minMoveMeters) {
      _points.add(point);
    }
  }

  /// Stops tracking, returns collected points, and resets state.
  List<LatLng> stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    final result = List<LatLng>.from(_points);
    _points.clear();
    return result;
  }
}
