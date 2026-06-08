// flutter/lib/features/drawing/drawing_result_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

const _bg     = Color(0xFF0A0A0A);
const _card   = Color(0xFF141414);
const _card2  = Color(0xFF1C1C1C);
const _muted  = Color(0x59FFFFFF);
const _border = Color(0x12FFFFFF);
const _orange = Color(0xFFFF6B1A);

class DrawingResultScreen extends StatefulWidget {
  final List<LatLng> path;

  const DrawingResultScreen({super.key, required this.path});

  @override
  State<DrawingResultScreen> createState() => _DrawingResultScreenState();
}

class _DrawingResultScreenState extends State<DrawingResultScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  double get _totalKm {
    if (widget.path.length < 2) return 0;
    double d = 0;
    for (int i = 1; i < widget.path.length; i++) {
      d += const Distance()
          .as(LengthUnit.Meter, widget.path[i - 1], widget.path[i]);
    }
    return d / 1000;
  }

  NCameraPosition _initialCamera() {
    final lats = widget.path.map((p) => p.latitude);
    final lngs = widget.path.map((p) => p.longitude);
    final centerLat =
        (lats.reduce((a, b) => a + b)) / widget.path.length;
    final centerLng =
        (lngs.reduce((a, b) => a + b)) / widget.path.length;
    return NCameraPosition(
      target: NLatLng(centerLat, centerLng),
      zoom: 15,
    );
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    final coords = widget.path
        .map((p) => NLatLng(p.latitude, p.longitude))
        .toList();

    // 경로 폴리라인
    await controller.addOverlay(NPolylineOverlay(
      id: 'drawing_path',
      coords: coords,
      color: _orange,
      width: 5,
      lineCap: NLineCap.round,
      lineJoin: NLineJoin.round,
    ));

    // 경계에 맞게 카메라 이동
    final bounds = NLatLngBounds.from(coords);
    await controller.updateCamera(
      NCameraUpdate.fitBounds(bounds,
          padding: const EdgeInsets.all(60)),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'my_drawing.png', mimeType: 'image/png')],
        text: '내땅내밟 드로잉 모드 🎨 ${_totalKm.toStringAsFixed(2)}km 달려서 그렸어요!',
      );
    } catch (e) {
      debugPrint('share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── 지도 (캡처 대상) ──
          Positioned.fill(
            bottom: 130 + bottom,
            child: RepaintBoundary(
              key: _repaintKey,
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: _initialCamera(),
                  mapType: NMapType.basic,
                  activeLayerGroups: [
                    NLayerGroup.building,
                    NLayerGroup.transit,
                  ],
                  consumeSymbolTapEvents: false,
                ),
                onMapReady: _onMapReady,
              ),
            ),
          ),

          // ── 상단 바 ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                  top: top + 8, left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                color: _bg.withValues(alpha: 0.92),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _card2,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '드로잉 완료',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 하단 패널 ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(14, 16, 14, bottom + 20),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _totalKm.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'km',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _sharing ? null : _shareImage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40FF6B1A),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _sharing
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Text(
                              '이미지로 공유',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
