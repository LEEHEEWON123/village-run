// flutter/lib/features/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../history/run_repository.dart';

const _green = Color(0xFF5C9E3A);
const _greenLight = Color(0xFFEBF5E0);
const _textDark = Color(0xFF1E2E14);
const _textSoft = Color(0xFF8AAA70);
const _border = Color(0xFFDCE8D0);
const _bg = Color(0xFFF7FAF3);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = RunRepository();
  late Future<List<RunRecord>> _runsFuture;

  @override
  void initState() {
    super.initState();
    _runsFuture = _repo.fetchRuns();
  }

  String _formatArea(double areaM2) {
    if (areaM2 >= 1000000) return '${(areaM2 / 1000000).toStringAsFixed(2)} km²';
    if (areaM2 >= 10000) return '${(areaM2 / 10000).toStringAsFixed(1)} 만m²';
    return '${areaM2.toStringAsFixed(0)} m²';
  }

  String _formatDist(double distM) {
    if (distM >= 1000) return '${(distM / 1000).toStringAsFixed(1)} km';
    return '${distM.toStringAsFixed(0)} m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}월 ${dt.day}일';
  }

  void _share() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final url = '${AppConstants.shareBaseUrl}/$userId';
    Share.share('내 나온김에 런 땅따먹기 현황 👀\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<RunRecord>>(
        future: _runsFuture,
        builder: (context, snapshot) {
          final runs = snapshot.data ?? [];
          final totalDist = runs.fold(0.0, (s, r) => s + r.distanceM);
          final totalArea = runs.fold(0.0, (s, r) => s + r.areaM2);

          return CustomScrollView(
            slivers: [
              // ── 상단 바 ──
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: top + 8,
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 15, color: _green),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '기록',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _share,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(Icons.ios_share_rounded,
                              size: 16, color: _green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 요약 ──
              if (runs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x305C9E3A),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('총 거리',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xAAFFFFFF),
                                        letterSpacing: 1)),
                                const SizedBox(height: 3),
                                Text(
                                  _formatDist(totalDist),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('총 점령 면적',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xAAFFFFFF),
                                      letterSpacing: 1)),
                              const SizedBox(height: 3),
                              Text(
                                _formatArea(totalArea),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white),
                              ),
                              Text(
                                '${runs.length}회',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xAAFFFFFF)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── 로딩 / 빈 상태 ──
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _green),
                  ),
                )
              else if (runs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      '아직 기록이 없어요\n첫 러닝을 시작해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textSoft,
                        height: 1.6,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RunCard(
                          run: runs[i],
                          formatDist: _formatDist,
                          formatArea: _formatArea,
                          formatDate: _formatDate,
                        ),
                      ),
                      childCount: runs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final RunRecord run;
  final String Function(double) formatDist;
  final String Function(double) formatArea;
  final String Function(DateTime) formatDate;

  const _RunCard({
    required this.run,
    required this.formatDist,
    required this.formatArea,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(run.startedAt),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _textSoft,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  formatDist(run.distanceM),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _textDark),
                ),
                Text(
                  formatArea(run.areaM2),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textSoft),
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.ios_share_rounded, size: 14, color: _green),
          ),
        ],
      ),
    );
  }
}
