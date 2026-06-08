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
  final _mapController = MapController();
  bool _centeredOnUser = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.loadTerritories();
    _controller.fetchCurrentLocation();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    if (!_centeredOnUser && _controller.currentLocation != null) {
      _centeredOnUser = true;
      _mapController.move(_controller.currentLocation!, 15);
    }
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
      backgroundColor: const Color(0xFFF5F0E8),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(37.5665, 126.9780),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.villagerun.app',
              ),
              PolygonLayer(
                polygons: _controller.completedTerritories
                    .map(_geoJsonToPolygon)
                    .whereType<Polygon>()
                    .toList(),
              ),
              if (_controller.currentLocation != null && !_controller.isTracking)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentLocation!,
                      child: _CurrentLocationDot(),
                    ),
                  ],
                ),
              if (_controller.currentPath.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.currentPath,
                      color: const Color(0xFF0064FF),
                      strokeWidth: 4,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentPath.last,
                      child: _CurrentLocationDot(),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // 상단 앱 타이틀바 (카카오맵 스타일)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text(
                    '나온김에 런',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF191F28),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  _IconBtn(
                    icon: Icons.history,
                    heroTag: 'history',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 내 위치로 이동 버튼 (우하단, 카카오맵 스타일)
          Positioned(
            right: 16,
            bottom: 120,
            child: _MapIconButton(
              icon: Icons.my_location,
              onTap: () {
                if (_controller.currentLocation != null) {
                  _mapController.move(_controller.currentLocation!, 15);
                } else {
                  _controller.fetchCurrentLocation();
                }
              },
            ),
          ),

          // 시작/종료 버튼 (하단 중앙)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _controller.isTracking
                  ? _RunButton(
                      label: '종료',
                      icon: Icons.stop_rounded,
                      color: const Color(0xFFFF4444),
                      onTap: _controller.stopRun,
                    )
                  : _RunButton(
                      label: '시작',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF0064FF),
                      onTap: _controller.startRun,
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
        color: const Color(0xFF0064FF).withValues(alpha: 0.20),
        borderColor: const Color(0xFF0064FF),
        borderStrokeWidth: 2,
      );
    } catch (e, st) {
      debugPrint('_geoJsonToPolygon: $e\n$st');
      return null;
    }
  }
}

// 현재 위치 파란 점 (카카오맵 스타일: 흰 테두리 + 파란 점 + 외곽 반투명 원)
class _CurrentLocationDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF0064FF).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0064FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

// 상단 아이콘 버튼
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String heroTag;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF191F28)),
      ),
    );
  }
}

// 지도 위 플로팅 아이콘 버튼 (카카오맵 원형 흰 버튼)
class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF0064FF)),
      ),
    );
  }
}

// 시작/종료 버튼 (카카오맵 하단 둥근 버튼)
class _RunButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RunButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
