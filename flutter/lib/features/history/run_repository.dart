// flutter/lib/features/history/run_repository.dart
import 'package:latlong2/latlong.dart';
import '../../core/supabase_client.dart';
import '../tracking/territory_calculator.dart';

class RunRecord {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final double areaM2;
  final List<LatLng> path;
  final String territoryGeoJson;

  const RunRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.areaM2,
    required this.path,
    required this.territoryGeoJson,
  });

  factory RunRecord.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['path'] as List)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();
    return RunRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      distanceM: (json['distance_m'] as num).toDouble(),
      areaM2: (json['area_m2'] as num).toDouble(),
      path: rawPath,
      territoryGeoJson: json['territory_geojson'] as String? ?? '',
    );
  }
}

class RunRepository {
  String get _userId {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  Future<void> saveRun({
    required DateTime startedAt,
    required DateTime endedAt,
    required List<LatLng> path,
    required TerritoryResult territory,
  }) async {
    try {
      final userId = _userId;

      final pathJson = path
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();

      // Calculate total path distance
      double distanceM = 0;
      for (int i = 0; i < path.length - 1; i++) {
        distanceM += const Distance().as(LengthUnit.Meter, path[i], path[i + 1]);
      }

      // Save run record
      await supabase.from('runs').insert({
        'user_id': userId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'distance_m': distanceM,
        'area_m2': territory.areaM2,
        'path': pathJson,
        'territory': territory.geoJson,           // PostGIS geometry
        'territory_geojson': territory.geoJson,   // text for web page
      });

      // Update cumulative territory via DB function
      await supabase.rpc('upsert_user_territory', params: {
        'p_user_id': userId,
        'p_new_territory': territory.geoJson,
        'p_new_area': territory.areaM2,
      });
    } on Object catch (e) {
      throw Exception('러닝 저장 실패: $e');
    }
  }

  Future<List<RunRecord>> fetchRuns() async {
    final userId = _userId;
    final data = await supabase
        .from('runs')
        .select('id, user_id, started_at, ended_at, distance_m, area_m2, path, territory_geojson')
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    return data.map((j) => RunRecord.fromJson(j)).toList();
  }

  Future<List<RunRecord>> fetchRunsByUserId(String userId) async {
    final data = await supabase
        .from('runs')
        .select('id, user_id, started_at, ended_at, distance_m, area_m2, path, territory_geojson')
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    return data.map((j) => RunRecord.fromJson(j)).toList();
  }
}
