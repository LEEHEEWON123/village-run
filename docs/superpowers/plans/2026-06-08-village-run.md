# village-run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 실제 GPS 경로로 지도 위 땅따먹기를 하고, 링크로 공유할 수 있는 Flutter 앱 + 웹 페이지 구축

**Architecture:** Flutter 앱이 GPS를 기록하고 PostGIS로 영역을 계산해 Supabase에 저장한다. 공유 링크는 Vercel에 배포된 정적 HTML 페이지가 Supabase REST API로 데이터를 읽어 Leaflet.js로 렌더링한다.

**Tech Stack:** Flutter, flutter_map, geolocator, supabase_flutter, google_sign_in, Supabase (PostgreSQL + PostGIS), Vercel (HTML + Leaflet.js)

---

## 파일 구조

```
village-run/
├── flutter/                          # Flutter 앱
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart                 # 앱 진입점, Supabase 초기화
│   │   ├── app.dart                  # MaterialApp, 라우팅
│   │   ├── core/
│   │   │   ├── supabase_client.dart  # Supabase 싱글턴
│   │   │   └── constants.dart        # 버퍼 거리(5m), 루프 감지(20m) 등
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── auth_service.dart         # Google OAuth 로직
│   │   │   │   └── login_screen.dart         # 로그인 화면
│   │   │   ├── map/
│   │   │   │   ├── map_screen.dart           # 홈 지도 화면
│   │   │   │   ├── map_controller.dart       # 지도 상태 관리
│   │   │   │   └── territory_painter.dart    # 영역 오버레이 위젯
│   │   │   ├── tracking/
│   │   │   │   ├── tracking_service.dart     # GPS 수집, 루프 감지
│   │   │   │   └── territory_calculator.dart # 버퍼+폴리곤 계산
│   │   │   └── history/
│   │   │       ├── history_screen.dart       # 기록 카드 리스트
│   │   │       └── run_repository.dart       # Supabase runs CRUD
│   └── test/
│       ├── territory_calculator_test.dart
│       └── tracking_service_test.dart
├── web/                              # 공유 웹 페이지
│   ├── index.html                    # /share/{user_id} 렌더링
│   └── vercel.json                   # Vercel 라우팅 설정
└── supabase/
    └── migrations/
        ├── 001_init.sql              # 테이블 + PostGIS 확장
        └── 002_rls.sql               # Row Level Security
```

---

## Task 1: Supabase 프로젝트 설정 + DB 마이그레이션

**Files:**
- Create: `supabase/migrations/001_init.sql`
- Create: `supabase/migrations/002_rls.sql`

- [ ] **Step 1: Supabase 프로젝트 생성**

  1. https://supabase.com/dashboard 에서 새 프로젝트 생성
  2. 프로젝트 이름: `village-run`
  3. 비밀번호 메모, 지역: Northeast Asia (Seoul)
  4. Settings → API 에서 `Project URL`과 `anon public key` 복사해 둠

- [ ] **Step 2: 001_init.sql 작성**

```sql
-- supabase/migrations/001_init.sql

-- PostGIS 확장 활성화
create extension if not exists postgis;

-- users 테이블 (Supabase auth.users 미러)
create table public.users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  avatar_url   text,
  created_at   timestamptz default now()
);

-- runs 테이블
create table public.runs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  started_at        timestamptz not null,
  ended_at          timestamptz not null,
  distance_m        float not null default 0,
  area_m2           float not null default 0,
  path              jsonb not null default '[]',     -- [{lat, lng, ts}]
  territory         geometry(Geometry, 4326),         -- PostGIS POLYGON (공간 연산용)
  territory_geojson text,                             -- GeoJSON 문자열 (웹 페이지 렌더링용)
  created_at        timestamptz default now()
);

-- user_territory 테이블 (누적 영역)
create table public.user_territory (
  user_id          uuid primary key references public.users(id) on delete cascade,
  total_area_m2    float not null default 0,
  merged_territory geometry(Geometry, 4326),
  updated_at       timestamptz default now()
);

-- runs 인덱스
create index runs_user_id_idx on public.runs(user_id);
create index runs_territory_idx on public.runs using gist(territory);
create index user_territory_idx on public.user_territory using gist(merged_territory);

-- auth.users 신규 가입 시 public.users 자동 생성 트리거
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

- [ ] **Step 3: 002_rls.sql 작성**

```sql
-- supabase/migrations/002_rls.sql

-- users RLS
alter table public.users enable row level security;

create policy "users: 본인만 수정" on public.users
  for all using (auth.uid() = id);

create policy "users: 누구나 읽기" on public.users
  for select using (true);

-- runs RLS
alter table public.runs enable row level security;

create policy "runs: 본인만 쓰기" on public.runs
  for all using (auth.uid() = user_id);

create policy "runs: 누구나 읽기" on public.runs
  for select using (true);

-- user_territory RLS
alter table public.user_territory enable row level security;

create policy "territory: 본인만 쓰기" on public.user_territory
  for all using (auth.uid() = user_id);

create policy "territory: 누구나 읽기" on public.user_territory
  for select using (true);
```

- [ ] **Step 4: Supabase SQL Editor에서 마이그레이션 실행**

  Supabase Dashboard → SQL Editor → 001_init.sql 내용 붙여넣기 → Run  
  이어서 002_rls.sql 내용 붙여넣기 → Run

  확인: Table Editor에서 `users`, `runs`, `user_territory` 테이블 생성됨

- [ ] **Step 5: Google OAuth 설정**

  1. Supabase Dashboard → Authentication → Providers → Google → Enable
  2. Google Cloud Console (console.cloud.google.com) → 새 프로젝트 또는 기존 프로젝트
  3. APIs & Services → Credentials → OAuth 2.0 Client ID 생성
     - Application type: Android (+ iOS 각각)
     - Android: 패키지명 `com.villagerun.app`, SHA-1 fingerprint (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`)
     - iOS: Bundle ID `com.villagerun.app`
  4. Client ID, Client Secret → Supabase Google Provider에 입력
  5. Supabase Redirect URL 복사 → Google Cloud Console Authorized redirect URIs에 추가

- [ ] **Step 6: 커밋**

```bash
git add supabase/
git commit -m "feat: add supabase migrations and RLS policies"
```

---

## Task 2: Flutter 프로젝트 초기화

**Files:**
- Create: `flutter/pubspec.yaml`
- Create: `flutter/lib/main.dart`
- Create: `flutter/lib/app.dart`
- Create: `flutter/lib/core/supabase_client.dart`
- Create: `flutter/lib/core/constants.dart`
- Create: `flutter/.env` (gitignore에 추가)

- [ ] **Step 1: Flutter 프로젝트 생성**

```bash
cd /Users/leeheewon/Documents/village-run
flutter create flutter --org com.villagerun --project-name village_run
cd flutter
```

- [ ] **Step 2: pubspec.yaml 의존성 추가**

`flutter/pubspec.yaml` 의 `dependencies:` 섹션을 아래로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.6
  google_sign_in: ^6.2.1
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^12.0.0
  share_plus: ^9.0.0
  flutter_dotenv: ^5.1.0
  uuid: ^4.4.0
```

```bash
flutter pub get
```

- [ ] **Step 3: .env 파일 생성 (gitignore에 추가)**

```
# flutter/.env
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

`.gitignore`에 추가:
```
flutter/.env
```

pubspec.yaml assets 섹션에 추가:
```yaml
flutter:
  assets:
    - .env
```

- [ ] **Step 4: core/constants.dart 작성**

```dart
// flutter/lib/core/constants.dart

class AppConstants {
  // 경로 버퍼 너비 (미터)
  static const double pathBufferMeters = 5.0;

  // 루프 감지 거리 (미터) - 시작점에 이 거리 이내 근접 시 루프 판정
  static const double loopDetectionMeters = 20.0;

  // GPS 최소 이동 거리 (미터) - 이 이하는 포인트 무시 (노이즈 제거)
  static const double minMoveMeters = 3.0;

  // GPS 업데이트 간격 (밀리초)
  static const int gpsIntervalMs = 1000;

  // 공유 페이지 베이스 URL
  static const String shareBaseUrl = 'https://village-run.vercel.app/share';
}
```

- [ ] **Step 5: core/supabase_client.dart 작성**

```dart
// flutter/lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;
```

- [ ] **Step 6: main.dart 작성**

```dart
// flutter/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const VillageRunApp());
}
```

- [ ] **Step 7: app.dart 작성**

```dart
// flutter/lib/app.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_screen.dart';
import 'features/map/map_screen.dart';

class VillageRunApp extends StatelessWidget {
  const VillageRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Village Run',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
        useMaterial3: true,
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginScreen()
          : const MapScreen(),
    );
  }
}
```

- [ ] **Step 8: 앱이 뜨는지 확인**

```bash
cd flutter
flutter run
```

빈 화면이라도 크래시 없이 실행되면 OK

- [ ] **Step 9: 커밋**

```bash
git add flutter/
git commit -m "feat: initialize flutter project with dependencies"
```

---

## Task 3: Google 로그인 화면

**Files:**
- Create: `flutter/lib/features/auth/auth_service.dart`
- Create: `flutter/lib/features/auth/login_screen.dart`

- [ ] **Step 1: auth_service.dart 작성**

```dart
// flutter/lib/features/auth/auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<AuthResponse> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google 로그인 취소됨');

    final googleAuth = await googleUser.authentication;
    if (googleAuth.accessToken == null || googleAuth.idToken == null) {
      throw Exception('Google 인증 토큰 없음');
    }

    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
  }

  User? get currentUser => Supabase.instance.client.auth.currentUser;
}
```

- [ ] **Step 2: pubspec.yaml에 flutter_svg 추가**

`flutter/pubspec.yaml` dependencies에 추가:
```yaml
  flutter_svg: ^2.0.10+1
```
```bash
flutter pub get
```

- [ ] **Step 3: login_screen.dart 작성**

```dart
// flutter/lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth_service.dart';
import '../map/map_screen.dart';

// Google 공식 브랜딩 가이드라인 준수 버튼
// https://developers.google.com/identity/branding-guidelines
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.onPressed});

  // Google 공식 "G" 로고 SVG
  static const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
  <path fill="none" d="M0 0h48v48H0z"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        minimumSize: const Size(240, 48),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(_googleLogoSvg, width: 24, height: 24),
          const SizedBox(width: 12),
          const Text(
            'Google로 계속하기',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Village Run',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '걷는 만큼 내 땅이 된다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _isLoading
                ? const CircularProgressIndicator()
                : _GoogleSignInButton(onPressed: _signIn),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Android google-services.json 추가**

  Google Cloud Console → 앱 등록에서 `google-services.json` 다운로드  
  → `flutter/android/app/google-services.json` 에 저장  
  `.gitignore`에 추가: `flutter/android/app/google-services.json`

  `flutter/android/build.gradle` → `dependencies`에 추가:
  ```
  classpath 'com.google.gms:google-services:4.4.1'
  ```

  `flutter/android/app/build.gradle` 하단에 추가:
  ```
  apply plugin: 'com.google.gms.google-services'
  ```

- [ ] **Step 5: iOS GoogleService-Info.plist 추가**

  Google Cloud Console → iOS 앱 등록에서 `GoogleService-Info.plist` 다운로드  
  → Xcode에서 `Runner/GoogleService-Info.plist`로 추가  
  `.gitignore`에 추가: `flutter/ios/Runner/GoogleService-Info.plist`

- [ ] **Step 6: 로그인 동작 확인**

```bash
flutter run
```

  Google 로그인 버튼 탭 → Google 계정 선택 → 지도 화면(빈 화면)으로 이동 확인

- [ ] **Step 7: 커밋**

```bash
git add flutter/lib/features/auth/
git commit -m "feat: add Google OAuth login screen with official branding"
```

---

## Task 4: 영역 계산 엔진 (TDD)

**Files:**
- Create: `flutter/lib/features/tracking/territory_calculator.dart`
- Create: `flutter/test/territory_calculator_test.dart`

- [ ] **Step 1: 테스트 파일 작성 (실패 확인용)**

```dart
// flutter/test/territory_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_run/features/tracking/territory_calculator.dart';

void main() {
  group('TerritoryCalculator', () {
    test('직선 경로는 버퍼 면적을 반환한다', () {
      // 서울 기준 약 100m 직선 (위도 0.001 ≈ 111m)
      final path = [
        LatLng(37.5000, 126.9000),
        LatLng(37.5009, 126.9000),
      ];
      final result = TerritoryCalculator.calculate(path);

      // 100m × 10m(좌우 5m씩) = 1000m² 근사
      expect(result.areaM2, greaterThan(500));
      expect(result.areaM2, lessThan(2000));
      expect(result.isLoop, isFalse);
    });

    test('루프 경로는 내부 면적을 포함한다', () {
      // 대략 200m × 200m 정사각형 루프
      final path = [
        LatLng(37.5000, 126.9000),
        LatLng(37.5018, 126.9000),
        LatLng(37.5018, 126.9025),
        LatLng(37.5000, 126.9025),
        LatLng(37.5000, 126.9000), // 닫힘
      ];
      final result = TerritoryCalculator.calculate(path);

      // 200m × 200m = 40000m² 근사 (버퍼 포함하면 더 클 수 있음)
      expect(result.areaM2, greaterThan(30000));
      expect(result.isLoop, isTrue);
    });

    test('포인트 2개 미만이면 빈 결과를 반환한다', () {
      final result = TerritoryCalculator.calculate([LatLng(37.5, 126.9)]);
      expect(result.areaM2, equals(0));
      expect(result.geoJson, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
cd flutter
flutter test test/territory_calculator_test.dart
```

Expected: FAIL (`TerritoryCalculator` not found)

- [ ] **Step 3: territory_calculator.dart 구현**

```dart
// flutter/lib/features/tracking/territory_calculator.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';

class TerritoryResult {
  final double areaM2;
  final bool isLoop;
  final String geoJson; // GeoJSON Polygon/MultiPolygon 문자열

  const TerritoryResult({
    required this.areaM2,
    required this.isLoop,
    required this.geoJson,
  });

  static const empty = TerritoryResult(areaM2: 0, isLoop: false, geoJson: '');
}

class TerritoryCalculator {
  static const double _bufferDeg = 5.0 / 111320.0; // 5m → 도(degree) 근사

  static TerritoryResult calculate(List<LatLng> path) {
    if (path.length < 2) return TerritoryResult.empty;

    final isLoop = _isLoop(path);

    if (isLoop) {
      // 루프: 경로로 폴리곤 생성 후 면적 계산
      final coords = _toCoords(path);
      final area = _polygonAreaM2(path);
      final geoJson = _makePolygonGeoJson(coords);
      return TerritoryResult(areaM2: area, isLoop: true, geoJson: geoJson);
    } else {
      // 직선: 버퍼 면적 = 경로 길이 × 버퍼 너비(10m = 좌우 5m)
      final length = _pathLengthM(path);
      final area = length * 10.0;
      final bufferedCoords = _buildBufferPolygon(path);
      final geoJson = _makePolygonGeoJson(bufferedCoords);
      return TerritoryResult(areaM2: area, isLoop: false, geoJson: geoJson);
    }
  }

  // 시작점과 마지막 점이 20m 이내면 루프
  static bool _isLoop(List<LatLng> path) {
    if (path.length < 3) return false;
    final dist = const Distance().as(
      LengthUnit.Meter,
      path.first,
      path.last,
    );
    return dist <= 20.0;
  }

  // 경로 전체 길이 (m)
  static double _pathLengthM(List<LatLng> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += const Distance().as(LengthUnit.Meter, path[i], path[i + 1]);
    }
    return total;
  }

  // 폴리곤 면적 (Shoelace 공식, 구면 근사)
  static double _polygonAreaM2(List<LatLng> path) {
    const metersPerDegLat = 111320.0;
    double area = 0;
    final n = path.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = path[i].longitude *
          metersPerDegLat *
          cos(path[i].latitude * pi / 180);
      final yi = path[i].latitude * metersPerDegLat;
      final xj = path[j].longitude *
          metersPerDegLat *
          cos(path[j].latitude * pi / 180);
      final yj = path[j].latitude * metersPerDegLat;
      area += xi * yj - xj * yi;
    }
    return (area.abs() / 2.0);
  }

  // 버퍼 폴리곤: 경로 좌우로 _bufferDeg 만큼 확장
  static List<List<double>> _buildBufferPolygon(List<LatLng> path) {
    final left = <List<double>>[];
    final right = <List<double>>[];

    for (int i = 0; i < path.length - 1; i++) {
      final dx = path[i + 1].longitude - path[i].longitude;
      final dy = path[i + 1].latitude - path[i].latitude;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final nx = -dy / len * _bufferDeg;
      final ny = dx / len * _bufferDeg;
      left.add([path[i].longitude + nx, path[i].latitude + ny]);
      right.add([path[i].longitude - nx, path[i].latitude - ny]);
    }

    final last = path.last;
    final secondLast = path[path.length - 2];
    final dx = last.longitude - secondLast.longitude;
    final dy = last.latitude - secondLast.latitude;
    final len = sqrt(dx * dx + dy * dy);
    if (len > 0) {
      final nx = -dy / len * _bufferDeg;
      final ny = dx / len * _bufferDeg;
      left.add([last.longitude + nx, last.latitude + ny]);
      right.add([last.longitude - nx, last.latitude - ny]);
    }

    return [...left, ...right.reversed, left.first];
  }

  static List<List<double>> _toCoords(List<LatLng> path) =>
      path.map((p) => [p.longitude, p.latitude]).toList();

  static String _makePolygonGeoJson(List<List<double>> coords) {
    final coordStr =
        coords.map((c) => '[${c[0]},${c[1]}]').join(',');
    return '{"type":"Polygon","coordinates":[[$coordStr]]}';
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
flutter test test/territory_calculator_test.dart
```

Expected: 3 tests PASS

- [ ] **Step 5: 커밋**

```bash
git add flutter/lib/features/tracking/territory_calculator.dart \
        flutter/test/territory_calculator_test.dart
git commit -m "feat: add territory calculator with buffer and loop detection"
```

---

## Task 5: GPS 추적 서비스 (TDD)

**Files:**
- Create: `flutter/lib/features/tracking/tracking_service.dart`
- Create: `flutter/test/tracking_service_test.dart`

- [ ] **Step 1: 테스트 파일 작성**

```dart
// flutter/test/tracking_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_run/features/tracking/tracking_service.dart';

void main() {
  group('TrackingService', () {
    late TrackingService service;

    setUp(() {
      service = TrackingService();
    });

    test('시작 전에는 포인트가 없다', () {
      expect(service.points, isEmpty);
      expect(service.isTracking, isFalse);
    });

    test('addPoint는 3m 이상 이동 시에만 포인트를 추가한다', () {
      service.startTracking();

      // 첫 번째 포인트 (항상 추가)
      service.addPoint(LatLng(37.5000, 126.9000));
      expect(service.points.length, 1);

      // 1m 이동 → 무시
      service.addPoint(LatLng(37.50001, 126.9000));
      expect(service.points.length, 1);

      // 10m 이동 → 추가
      service.addPoint(LatLng(37.5001, 126.9000));
      expect(service.points.length, 2);
    });

    test('stopTracking은 포인트 목록을 반환하고 초기화한다', () {
      service.startTracking();
      service.addPoint(LatLng(37.5000, 126.9000));
      service.addPoint(LatLng(37.5010, 126.9000));

      final points = service.stopTracking();
      expect(points.length, 2);
      expect(service.points, isEmpty);
      expect(service.isTracking, isFalse);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
flutter test test/tracking_service_test.dart
```

Expected: FAIL

- [ ] **Step 3: tracking_service.dart 구현**

```dart
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

  // 실제 GPS 스트림 시작 (기기에서 호출)
  Future<void> startTracking() async {
    _points.clear();
    _isTracking = true;

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 필요합니다');
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // 3m 이상 이동 시에만 업데이트
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) {
      addPoint(LatLng(pos.latitude, pos.longitude));
    });
  }

  // 테스트에서 직접 포인트 주입 가능하도록 분리
  void addPoint(LatLng point) {
    if (!_isTracking) return;

    if (_points.isEmpty) {
      _points.add(point);
      return;
    }

    final dist = const Distance().as(
      LengthUnit.Meter,
      _points.last,
      point,
    );

    if (dist >= AppConstants.minMoveMeters) {
      _points.add(point);
    }
  }

  List<LatLng> stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    final result = List<LatLng>.from(_points);
    _points.clear();
    return result;
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
flutter test test/tracking_service_test.dart
```

Expected: 3 tests PASS

- [ ] **Step 5: 커밋**

```bash
git add flutter/lib/features/tracking/tracking_service.dart \
        flutter/test/tracking_service_test.dart
git commit -m "feat: add GPS tracking service with noise filtering"
```

---

## Task 6: Supabase 데이터 저장 (run_repository)

**Files:**
- Create: `flutter/lib/features/history/run_repository.dart`

- [ ] **Step 1: run_repository.dart 작성**

```dart
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
        .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
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
  Future<void> saveRun({
    required DateTime startedAt,
    required DateTime endedAt,
    required List<LatLng> path,
    required TerritoryResult territory,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final pathJson = path
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();

    // 경로 전체 길이 계산
    double distanceM = 0;
    for (int i = 0; i < path.length - 1; i++) {
      distanceM += const Distance().as(LengthUnit.Meter, path[i], path[i + 1]);
    }

    // runs 저장
    await supabase.from('runs').insert({
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'distance_m': distanceM,
      'area_m2': territory.areaM2,
      'path': pathJson,
      'territory': territory.geoJson,          // PostGIS geometry (공간 연산용)
      'territory_geojson': territory.geoJson,  // 텍스트 GeoJSON (웹 페이지 렌더링용)
    });

    // user_territory 누적 업데이트 (upsert + PostGIS ST_Union은 DB 함수로)
    await supabase.rpc('upsert_user_territory', params: {
      'p_user_id': userId,
      'p_new_territory': territory.geoJson,
      'p_new_area': territory.areaM2,
    });
  }

  Future<List<RunRecord>> fetchRuns() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('runs')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    return (data as List).map((j) => RunRecord.fromJson(j)).toList();
  }

  Future<List<RunRecord>> fetchRunsByUserId(String userId) async {
    final data = await supabase
        .from('runs')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    return (data as List).map((j) => RunRecord.fromJson(j)).toList();
  }
}
```

- [ ] **Step 2: Supabase DB 함수 추가**

Supabase SQL Editor에서 실행:

```sql
create or replace function upsert_user_territory(
  p_user_id uuid,
  p_new_territory text,
  p_new_area float
) returns void language plpgsql security definer as $$
declare
  v_new_geom geometry := ST_GeomFromGeoJSON(p_new_territory);
  v_existing geometry;
begin
  select merged_territory into v_existing
  from public.user_territory
  where user_id = p_user_id;

  if v_existing is null then
    insert into public.user_territory (user_id, total_area_m2, merged_territory)
    values (p_user_id, p_new_area, v_new_geom);
  else
    update public.user_territory
    set
      merged_territory = ST_Union(v_existing, v_new_geom),
      total_area_m2 = total_area_m2 + p_new_area,
      updated_at = now()
    where user_id = p_user_id;
  end if;
end;
$$;
```

- [ ] **Step 3: 커밋**

```bash
git add flutter/lib/features/history/run_repository.dart
git commit -m "feat: add run repository with Supabase persistence"
```

---

## Task 7: 지도 화면 (홈)

**Files:**
- Create: `flutter/lib/features/map/map_controller.dart`
- Create: `flutter/lib/features/map/map_screen.dart`

- [ ] **Step 1: map_controller.dart 작성**

```dart
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

  // 완료된 모든 회차 영역 (지도 오버레이용)
  List<String> completedTerritories = [];

  DateTime? _startedAt;

  Future<void> loadTerritories() async {
    final runs = await _repository.fetchRuns();
    completedTerritories =
        runs.map((r) => r.territoryGeoJson).where((g) => g.isNotEmpty).toList();
    notifyListeners();
  }

  Future<void> startRun() async {
    _startedAt = DateTime.now();
    await _trackingService.startTracking();
    notifyListeners();
  }

  Future<void> stopRun() async {
    final path = _trackingService.stopTracking();
    if (path.length < 2) {
      notifyListeners();
      return;
    }

    final territory = TerritoryCalculator.calculate(path);
    await _repository.saveRun(
      startedAt: _startedAt!,
      endedAt: DateTime.now(),
      path: path,
      territory: territory,
    );

    await loadTerritories();
    notifyListeners();
  }
}
```

- [ ] **Step 2: map_screen.dart 작성**

```dart
// flutter/lib/features/map/map_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'map_controller.dart';
import '../history/history_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();

  @override
  void initState() {
    super.initState();
    _controller.loadTerritories();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.villagerun.app',
              ),
              // 완료된 영역 오버레이
              PolygonLayer(
                polygons: _controller.completedTerritories
                    .map((geoJson) => _geoJsonToPolygon(geoJson))
                    .whereType<Polygon>()
                    .toList(),
              ),
              // 현재 기록 중인 경로
              if (_controller.currentPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _controller.currentPath,
                      color: Colors.white,
                      strokeWidth: 3,
                      isDotted: true,
                    ),
                  ],
                ),
              // 현재 위치 마커
              if (_controller.currentPath.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _controller.currentPath.last,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4285F4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        width: 16,
                        height: 16,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // 하단 버튼
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
          // 기록 버튼
          Positioned(
            top: 56,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              child: const Icon(Icons.history),
            ),
          ),
        ],
      ),
    );
  }

  Polygon? _geoJsonToPolygon(String geoJson) {
    try {
      // dart:convert로 안전하게 파싱
      // GeoJSON: {"type":"Polygon","coordinates":[[[lng,lat], ...]]}
      final decoded = jsonDecode(geoJson) as Map<String, dynamic>;
      final rawCoords =
          (decoded['coordinates'] as List).first as List;

      final points = rawCoords
          .map((c) => LatLng(
                (c[1] as num).toDouble(), // lat
                (c[0] as num).toDouble(), // lng
              ))
          .toList();

      if (points.isEmpty) return null;

      return Polygon(
        points: points,
        color: const Color(0xFF4285F4).withOpacity(0.35),
        borderColor: const Color(0xFF4285F4),
        borderStrokeWidth: 1.5,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 3: Android 위치 권한 추가**

`flutter/android/app/src/main/AndroidManifest.xml` `<manifest>` 안에 추가:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 4: iOS 위치 권한 추가**

`flutter/ios/Runner/Info.plist` 에 추가:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>러닝 경로 기록을 위해 위치 접근이 필요합니다</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>러닝 중 위치 추적을 위해 위치 접근이 필요합니다</string>
```

- [ ] **Step 5: 동작 확인**

```bash
flutter run
```

  - 지도 로드 확인
  - 시작 버튼 탭 → 권한 요청 → 경로 점선 표시
  - 종료 버튼 탭 → 영역 파란색으로 표시

- [ ] **Step 6: 커밋**

```bash
git add flutter/lib/features/map/
git commit -m "feat: add map screen with GPS tracking and territory overlay"
```

---

## Task 8: 기록 화면 + 공유 링크

**Files:**
- Create: `flutter/lib/features/history/history_screen.dart`

- [ ] **Step 1: history_screen.dart 작성**

```dart
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
```

- [ ] **Step 2: 동작 확인**

  - 기록 아이콘 탭 → 리스트 표시
  - 공유 아이콘 탭 → `village-run.vercel.app/share/{userId}` URL 포함된 공유 시트 표시

- [ ] **Step 3: 커밋**

```bash
git add flutter/lib/features/history/history_screen.dart
git commit -m "feat: add history screen with date cards and share link"
```

---

## Task 9: 공유 웹 페이지 (Vercel)

**Files:**
- Create: `web/index.html`
- Create: `web/vercel.json`

- [ ] **Step 1: vercel.json 작성**

```json
{
  "rewrites": [
    { "source": "/share/:userId", "destination": "/index.html" }
  ]
}
```

- [ ] **Step 2: index.html 작성**

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Village Run — 내 땅</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: flex; height: 100vh; }
    #map { flex: 1; }
    #sidebar {
      width: 280px; background: #fff; overflow-y: auto;
      border-left: 1px solid #eee; display: flex; flex-direction: column;
    }
    #sidebar-header {
      padding: 16px; border-bottom: 1px solid #eee;
      font-size: 18px; font-weight: 700;
    }
    #sidebar-subtitle { font-size: 12px; color: #888; margin-top: 2px; }
    .run-card {
      padding: 12px 16px; border-bottom: 1px solid #f0f0f0;
      cursor: pointer; transition: background 0.1s;
    }
    .run-card:hover { background: #f5f8ff; }
    .run-card.active { background: #e8f0fe; border-left: 3px solid #4285F4; }
    .run-date { font-weight: 600; font-size: 14px; }
    .run-meta { font-size: 12px; color: #666; margin-top: 2px; }
    @media (max-width: 600px) {
      body { flex-direction: column; }
      #map { flex: none; height: 60vh; }
      #sidebar { width: 100%; height: 40vh; border-left: none; border-top: 1px solid #eee; }
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="sidebar">
    <div id="sidebar-header">
      Village Run
      <div id="sidebar-subtitle">불러오는 중...</div>
    </div>
    <div id="run-list"></div>
  </div>

  <script>
    const SUPABASE_URL = 'YOUR_SUPABASE_URL';  // 배포 시 실제 값으로 교체
    const SUPABASE_KEY = 'YOUR_SUPABASE_ANON_KEY';

    const map = L.map('map').setView([37.5665, 126.9780], 13);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(map);

    const userId = location.pathname.split('/share/')[1];
    let layers = {};
    let allBounds = [];

    async function load() {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/runs?user_id=eq.${userId}&select=id,started_at,ended_at,distance_m,area_m2,territory_geojson&order=started_at.desc`,
        { headers: { 'apikey': SUPABASE_KEY, 'Authorization': `Bearer ${SUPABASE_KEY}` } }
      );
      const runs = await res.json();

      // 전체 영역 합산 표시
      const totalArea = runs.reduce((s, r) => s + (r.area_m2 || 0), 0);
      document.getElementById('sidebar-subtitle').textContent =
        `총 ${formatArea(totalArea)} 점령`;

      const list = document.getElementById('run-list');
      runs.forEach(run => {
        // 지도 레이어
        if (run.territory_geojson) {
          try {
            const geom = JSON.parse(run.territory_geojson);
            const layer = L.geoJSON(geom, {
              style: { color: '#4285F4', fillColor: '#4285F4', fillOpacity: 0.35, weight: 1.5 }
            }).addTo(map);
            layers[run.id] = layer;
            allBounds.push(layer.getBounds());
          } catch(e) {}
        }

        // 사이드바 카드
        const card = document.createElement('div');
        card.className = 'run-card';
        card.dataset.id = run.id;
        const d = new Date(run.started_at);
        card.innerHTML = `
          <div class="run-date">${d.getMonth()+1}/${d.getDate()} ${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}</div>
          <div class="run-meta">이동 ${formatDist(run.distance_m)} | 점령 ${formatArea(run.area_m2)}</div>
        `;
        card.onclick = () => focusRun(run.id);
        list.appendChild(card);
      });

      // 전체 영역에 맞게 지도 이동
      if (allBounds.length > 0) {
        const combined = allBounds.reduce((a, b) => a.extend(b));
        map.fitBounds(combined, { padding: [20, 20] });
      }
    }

    function focusRun(id) {
      document.querySelectorAll('.run-card').forEach(c => c.classList.remove('active'));
      document.querySelector(`.run-card[data-id="${id}"]`)?.classList.add('active');

      // 선택된 것만 강조
      Object.entries(layers).forEach(([lid, layer]) => {
        layer.setStyle(lid === id
          ? { fillOpacity: 0.6, weight: 2.5 }
          : { fillOpacity: 0.2, weight: 1 });
      });

      if (layers[id]) map.fitBounds(layers[id].getBounds(), { padding: [40, 40] });
    }

    function formatArea(m2) {
      if (!m2) return '0 m²';
      if (m2 >= 1e6) return `${(m2/1e6).toFixed(2)} km²`;
      if (m2 >= 10000) return `${(m2/10000).toFixed(1)} 만m²`;
      return `${Math.round(m2)} m²`;
    }

    function formatDist(m) {
      if (!m) return '0 m';
      return m >= 1000 ? `${(m/1000).toFixed(1)} km` : `${Math.round(m)} m`;
    }

    load();
  </script>
</body>
</html>
```

- [ ] **Step 3: Vercel 배포**

```bash
# Vercel CLI 설치 (없으면)
npm i -g vercel

cd /Users/leeheewon/Documents/village-run/web
vercel --prod
```

  - 도메인 확인 후 `AppConstants.shareBaseUrl` 실제 URL로 업데이트
  - `index.html`의 `SUPABASE_URL`, `SUPABASE_KEY` 실제 값으로 교체

- [ ] **Step 4: 커밋**

```bash
git add web/
git commit -m "feat: add share web page with Leaflet.js and run history"
```

---

## Task 10: 전체 통합 테스트

- [ ] **Step 1: 전체 테스트 실행**

```bash
cd flutter
flutter test
```

Expected: 모든 테스트 PASS

- [ ] **Step 2: 실기기 E2E 확인**

  1. 앱 실행 → Google 로그인
  2. 시작 버튼 → 걸어서 루프 형성 → 종료
  3. 파란 영역 지도에 표시 확인
  4. 기록 탭 → 카드 리스트 확인
  5. 공유 버튼 → 링크 복사 → 브라우저에서 열기
  6. 웹 페이지에서 영역 + 카드 리스트 확인

- [ ] **Step 3: 최종 커밋**

```bash
git add -A
git commit -m "feat: village-run MVP complete"
```
