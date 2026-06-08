// flutter/lib/features/map/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_controller.dart' as app_map;
import '../tracking/run_mode.dart';
import '../history/history_screen.dart';
import '../drawing/drawing_result_screen.dart';

const _green = Color(0xFF5C9E3A);
const _greenLight = Color(0xFFEBF5E0);
const _textDark = Color(0xFF1E2E14);
const _textSoft = Color(0xFF8AAA70);
const _border = Color(0xFFDCE8D0);
const _drawColor = Color(0xFFE87820);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = app_map.MapController();
  final _mapController = MapController();
  bool _centeredOnUser = false;
  int? _countdown; // 3, 2, 1, null = 없음

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

    // 내 위치 최초 이동
    if (!_centeredOnUser && _controller.currentLocation != null) {
      _centeredOnUser = true;
      _mapController.move(_controller.currentLocation!, 15);
    }

    // 드로잉 완료 → 결과 화면으로
    if (_controller.completedDrawingPath != null) {
      final path = _controller.completedDrawingPath!;
      _controller.clearDrawingPath();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DrawingResultScreen(path: path),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onStartTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModeSheet(
        onSelect: (mode) {
          Navigator.pop(context);
          _startCountdown(mode);
        },
      ),
    );
  }

  Future<void> _startCountdown(RunMode mode) async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _countdown = null);
    _controller.startRun(mode);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isDrawing = _controller.runMode == RunMode.drawing;

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
              // 땅따먹기 폴리곤
              PolygonLayer(
                polygons: _controller.completedTerritories
                    .map(_geoJsonToPolygon)
                    .whereType<Polygon>()
                    .toList(),
              ),
              // 현재 위치 점 (대기 중)
              if (_controller.currentLocation != null && !_controller.isTracking)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentLocation!,
                      child: const _LocationDot(color: _green),
                    ),
                  ],
                ),
              // 경로 선
              if (_controller.currentPath.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.currentPath,
                      color: isDrawing ? _drawColor : _green.withValues(alpha: 0.9),
                      strokeWidth: isDrawing ? 5 : 3.5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                      pattern: isDrawing
                          ? const StrokePattern.solid()
                          : const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentPath.last,
                      child: _LocationDot(
                          color: isDrawing ? _drawColor : _green),
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
                  top: top + 8, left: 16, right: 16, bottom: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    _controller.isTracking
                        ? (isDrawing ? '🎨 드로잉 중' : '● 기록 중')
                        : '내땅내밟',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _controller.isTracking
                          ? (isDrawing ? _drawColor : const Color(0xFFD94020))
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
                        offset: Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 18, color: _green),
              ),
            ),
          ),

          // ── 카운트다운 오버레이 ──
          if (_countdown != null)
            Positioned.fill(
              child: Container(
                color: const Color(0x88000000),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
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
                border: Border(top: BorderSide(color: _border)),
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
                          label: isDrawing ? '드로잉 완료' : '완료',
                          color: isDrawing
                              ? _drawColor
                              : const Color(0xFFE04828),
                          shadowColor: isDrawing
                              ? const Color(0x40E87820)
                              : const Color(0x40E04828),
                          onTap: _controller.stopRun,
                        )
                      : _MainButton(
                          label: '달리기 시작',
                          color: _green,
                          shadowColor: const Color(0x405C9E3A),
                          onTap: _countdown != null ? () {} : _onStartTap,
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

// ── 위젯들 ──

class _LocationDot extends StatelessWidget {
  final Color color;
  const _LocationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
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
        _Chip(value: '${path.length}', unit: 'pts'),
        const SizedBox(width: 8),
        _Chip(
          value: controller.runMode == RunMode.drawing ? '🎨' : '🗺️',
          unit: controller.runMode == RunMode.drawing ? 'draw' : 'map',
        ),
      ],
    );
  }

  double _calcDist(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    double d = 0;
    for (int i = 1; i < pts.length; i++) {
      d += const Distance().as(LengthUnit.Meter, pts[i - 1], pts[i]);
    }
    return d;
  }
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
            BoxShadow(
                color: shadowColor,
                blurRadius: 16,
                offset: const Offset(0, 4)),
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

// ── 모드 선택 바텀시트 ──
class _ModeSheet extends StatelessWidget {
  final void Function(RunMode) onSelect;
  const _ModeSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '모드 선택',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    emoji: '🗺️',
                    title: '땅따먹기',
                    desc: '달린 경로로\n내 땅을 만들어요',
                    color: _green,
                    onTap: () => onSelect(RunMode.territory),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeCard(
                    emoji: '🎨',
                    title: '드로잉',
                    desc: '달리면서\n그림을 그려요',
                    color: _drawColor,
                    onTap: () => onSelect(RunMode.drawing),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                )),
            const SizedBox(height: 4),
            Text(desc,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSoft,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}
