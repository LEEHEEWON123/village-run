// flutter/lib/features/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../history/run_repository.dart';

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
    if (areaM2 >= 1000000) {
      return '${(areaM2 / 1000000).toStringAsFixed(2)} km²';
    } else if (areaM2 >= 10000) {
      return '${(areaM2 / 10000).toStringAsFixed(1)} 만m²';
    }
    return '${areaM2.toStringAsFixed(0)} m²';
  }

  String _formatDistance(double distM) {
    if (distM >= 1000) return '${(distM / 1000).toStringAsFixed(1)} km';
    return '${distM.toStringAsFixed(0)} m';
  }

  void _share() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final url = '${AppConstants.shareBaseUrl}/$userId';
    Share.share('내 Village Run 땅따먹기 현황 👀\n$url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
            tooltip: '공유',
          ),
        ],
      ),
      body: FutureBuilder<List<RunRecord>>(
        future: _runsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          final runs = snapshot.data ?? [];
          if (runs.isEmpty) {
            return const Center(child: Text('아직 기록이 없어요. 첫 러닝을 시작해보세요!'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: runs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final run = runs[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.place, color: Color(0xFF4285F4)),
                  title: Text(
                    '${run.startedAt.month}/${run.startedAt.day} '
                    '${run.startedAt.hour.toString().padLeft(2, '0')}:'
                    '${run.startedAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '이동 ${_formatDistance(run.distanceM)}  |  '
                    '점령 ${_formatArea(run.areaM2)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
