// flutter/lib/features/map/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_controller.dart' as app_map;
import '../history/history_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = app_map.MapController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.loadTerritories();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(37.5665, 126.9780),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.villagerun.app',
              ),
              PolygonLayer(
                polygons: _controller.completedTerritories
                    .map(_geoJsonToPolygon)
                    .whereType<Polygon>()
                    .toList(),
              ),
              if (_controller.currentPath.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.currentPath,
                      color: Colors.white,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentPath.last,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          // History button (top right)
          Positioned(
            top: 56,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'history',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              child: const Icon(Icons.history),
            ),
          ),
          // Start/Stop button (bottom center)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: _controller.isTracking
                  ? ElevatedButton.icon(
                      onPressed: _controller.stopRun,
                      icon: const Icon(Icons.stop),
                      label: const Text('종료'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _controller.startRun,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('시작'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Polygon? _geoJsonToPolygon(String geoJson) {
    try {
      final decoded = jsonDecode(geoJson) as Map<String, dynamic>;
      final rawCoords = (decoded['coordinates'] as List).first as List;
      final points = rawCoords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      if (points.isEmpty) return null;
      return Polygon(
        points: points,
        color: const Color(0xFF4285F4).withValues(alpha: 0.35),
        borderColor: const Color(0xFF4285F4),
        borderStrokeWidth: 1.5,
      );
    } catch (_) {
      return null;
    }
  }
}
