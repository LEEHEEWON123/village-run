# village-run

걷거나 달린 경로로 지도 위 땅따먹기를 하는 Flutter 앱.

경로를 둘러싸면 내부 면적 전체가 내 땅이 되고, 직선 이동도 좌우 5m 버퍼 면적으로 인정된다.
기록은 Supabase에 저장되고, 공유 링크를 통해 누구나 브라우저에서 내 땅을 볼 수 있다.

## 스크린샷

[UI 목업](docs/ui-mockup.html) | [워크플로우](docs/workflow-overview.html)

## 아키텍처

```
Flutter App (iOS/Android)
    │ Supabase SDK
    ▼
Supabase (PostgreSQL + PostGIS)
    │ REST API
    ▼
공유 웹 페이지 (Firebase Hosting, Leaflet.js + OSM)
```

## 주요 기능

- **GPS 땅따먹기** — 걸어간 경로를 실시간 점선으로 표시, 종료 시 영역 계산
- **두 가지 영역 유형**
  - 루프(시작점 20m 이내 복귀): 내부 폴리곤 면적 전체
  - 직선: 경로 좌우 5m 버퍼 스트립
- **Google 로그인** — Supabase Auth + Google OAuth
- **기록 화면** — 일별 러닝 카드 (날짜, 이동 거리, 점령 면적)
- **공유 링크** — `https://village-run-app.web.app/share/{userId}` 브라우저에서 바로 확인

## 기술 스택

| 분류 | 기술 |
|------|------|
| 앱 | Flutter, flutter_map, geolocator, supabase_flutter, google_sign_in |
| 백엔드 | Supabase (PostgreSQL + PostGIS) |
| 공유 웹 | Firebase Hosting (Spark), HTML + Leaflet.js + OSM |

## 프로젝트 구조

```
village-run/
├── flutter/               # Flutter 앱 (iOS/Android)
│   ├── lib/
│   │   ├── features/
│   │   │   ├── auth/      # Google OAuth 로그인
│   │   │   ├── map/       # 지도 화면 + 컨트롤러
│   │   │   ├── tracking/  # GPS 추적, 영역 계산
│   │   │   └── history/   # 기록 화면, Supabase CRUD
│   │   └── core/          # 상수, Supabase 클라이언트
│   └── test/              # 유닛 테스트 (7개)
├── web/                   # 공유 웹 페이지
│   ├── index.html         # Leaflet.js 지도 + 기록 사이드바
│   ├── firebase.json      # Firebase Hosting 설정
│   └── .firebaserc        # Firebase 프로젝트 연결
└── supabase/
    └── migrations/        # DB 스키마 + RLS + 함수
```

## 시작하기

### 1. 환경변수 설정

```bash
cp flutter/.env.example flutter/.env
# SUPABASE_URL, SUPABASE_ANON_KEY 입력
```

### 2. 의존성 설치

```bash
cd flutter && flutter pub get
```

### 3. 실행

```bash
flutter run
```

### 4. 공유 웹 배포 (Firebase Hosting)

```bash
cd web
firebase login
firebase deploy --only hosting
```

## Google 로그인 설정

1. [Google Cloud Console](https://console.cloud.google.com) → OAuth 2.0 Client ID 생성 (Android / iOS / Web)
2. Supabase Dashboard → Authentication → Providers → Google → Client ID / Secret 입력
3. Supabase Redirect URL → Google Cloud Console Authorized redirect URIs에 추가
4. `flutter/android/app/google-services.json` 배치

## 테스트

```bash
cd flutter && flutter test
# 7 tests passed
```
