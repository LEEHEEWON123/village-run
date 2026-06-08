// flutter/lib/features/map/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_controller.dart' as app_map;
import '../history/history_screen.dart';

const _green = Color(0xFF5C9E3A);
const _greenLight = Color(0xFFEBF5E0);
const _textDark = Color(0xFF1E2E14);
const _textSoft = Color(0xFF8AAA70);
const _border = Color(0xFFDCE8D0);

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
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ── 지도 ──
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
                      child: const _LocationDot(),
                    ),
                  ],
                ),
              if (_controller.currentPath.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.currentPath,
                      color: const Color(0xFFE87820),
                      strokeWidth: 3.5,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentPath.last,
                      child: const _LocationDot(),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // ── 상단 바 ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    _controller.isTracking ? '● 기록 중' : '내땅내밟',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _controller.isTracking
                          ? const Color(0xFFD94020)
                          : _textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (!_controller.isTracking)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()),
                      ),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(Icons.history_rounded,
                            size: 18, color: _green),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 내 위치 버튼 ──
          Positioned(
            right: 14,
            bottom: bottom + 104,
            child: GestureDetector(
              onTap: () {
                if (_controller.currentLocation != null) {
                  _mapController.move(_controller.currentLocation!, 15);
                } else {
                  _controller.fetchCurrentLocation();
                }
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 18, color: _green),
              ),
            ),
          ),

          // ── 하단 패널 ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(14, 14, 14, bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: _border),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.isTracking) ...[
                    _StatRow(controller: _controller),
                    const SizedBox(height: 10),
                  ],
                  _controller.isTracking
                      ? _MainButton(
                          label: '완료',
                          color: const Color(0xFFE04828),
                          shadowColor: const Color(0x40E04828),
                          onTap: _controller.stopRun,
                        )
                      : _MainButton(
                          label: '달리기 시작',
                          color: _green,
                          shadowColor: const Color(0x405C9E3A),
                          onTap: _controller.startRun,
                        ),
                ],
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
        color: _green.withValues(alpha: 0.18),
        borderColor: _green,
        borderStrokeWidth: 2,
      );
    } catch (e, st) {
      debugPrint('_geoJsonToPolygon: $e\n$st');
      return null;
    }
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x405C9E3A), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final app_map.MapController controller;
  const _StatRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final path = controller.currentPath;
    final dist = _calcDist(path);
    return Row(
      children: [
        _Chip(value: (dist / 1000).toStringAsFixed(2), unit: 'km'),
        const SizedBox(width: 8),
        _Chip(value: _elapsed(controller), unit: 'time'),
        const SizedBox(width: 8),
        _Chip(value: '—', unit: 'm²'),
      ],
    );
  }

  double _calcDist(List points) {
    if (points.length < 2) return 0;
    double d = 0;
    for (int i = 1; i < points.length; i++) {
      d += const Distance().as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return d;
  }

  String _elapsed(app_map.MapController c) => '—';
}

class _Chip extends StatelessWidget {
  final String value;
  final String unit;
  const _Chip({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: _greenLight,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _textDark)),
            const SizedBox(height: 1),
            Text(unit,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _textSoft,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;

  const _MainButton({
    required this.label,
    required this.color,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: shadowColor, blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
