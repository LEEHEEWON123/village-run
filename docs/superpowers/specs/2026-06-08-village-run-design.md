# village-run 설계 문서

**작성일:** 2026-06-08  
**상태:** 승인됨

---

## 개요

실제 걷거나 달린 경로로 지도 위 땅따먹기를 하는 Flutter 모바일 앱.  
경로를 둘러싸면 내부 면적 전체가 내 땅이 되고, 직선 이동도 경로 좌우 5m 버퍼 면적으로 인정된다.  
기록은 Supabase에 저장되고, 공유 링크를 통해 누구나 브라우저에서 내 땅을 볼 수 있다.

---

## 아키텍처

```
Flutter App (iOS/Android)
    │
    │ Supabase SDK
    ▼
Supabase (PostgreSQL + PostGIS)
    │
    │ REST API
    ▼
공유 웹 페이지 (Vercel, Leaflet.js + OSM)
```

- **Flutter 앱**: GPS 기록, 영역 계산, 지도 시각화
- **Supabase**: 경로 및 영역 저장, PostGIS 지리 연산
- **Vercel 웹 페이지**: 공유 링크 렌더링 (앱 설치 불필요)

---

## 화면 구성

### 1. 홈 (지도 화면)
- OSM 지도 전체화면 (`flutter_map`)
- 지금까지 점령한 모든 땅 파란 반투명 오버레이
- 하단 "시작" 버튼 → GPS 기록 시작
- 기록 중: 현재 경로 흰 점선 실시간 표시
- "종료" 버튼 → 경로 닫힘 → 영역 계산 → 지도에 추가

### 2. 기록 화면
- 일별 러닝 카드 리스트 (날짜 / 이동 거리 / 점령 면적)
- 카드 탭 → 해당 회차 영역 지도 하이라이트
- 상단 공유 버튼 → 링크 클립보드 복사

### 3. 공유 웹 페이지 (`/share/{user_id}`)
- 지도 전체화면 + 전체 점령 영역 표시
- 우측 일별 카드 리스트
- 카드 클릭 → 해당 영역 하이라이트
- 읽기 전용

---

## 영역 계산 방식

### 두 가지 영역 유형
1. **경로 버퍼**: 걸어간 선을 좌우 5m 확장 → 직선도 면적 생성
2. **둘러싼 면적**: 경로가 루프를 형성하면 내부 전체 포함

### PostGIS 연산 흐름
```sql
-- 1. 경로 버퍼 (5m)
buffer_area = ST_Buffer(path_linestring, 5)

-- 2. 루프 감지 시 내부 폴리곤
enclosed_area = ST_MakePolygon(path_linestring)

-- 3. 회차 최종 영역
run_territory = ST_Union(buffer_area, enclosed_area)

-- 4. 누적 영역 갱신
new_total = ST_Union(user_territory.merged_territory, run_territory)
```

### 루프 감지 기준
- 현재 위치가 시작점으로부터 20m 이내에 근접 시 루프로 판정
- 종료 버튼 누를 때 시작점-종료점 자동 연결

---

## 데이터 모델

```sql
-- 유저 (익명, 회원가입 없음)
users
  id          uuid        PK  -- 앱 최초 실행 시 생성, 기기에 저장
  created_at  timestamptz

-- 러닝 회차
runs
  id            uuid        PK
  user_id       uuid        FK → users
  started_at    timestamptz
  ended_at      timestamptz
  distance_m    float       -- 총 이동 거리 (m)
  area_m2       float       -- 이번 회차 점령 면적 (m²)
  path          jsonb       -- GPS 좌표 배열 [{lat, lng, ts}]
  territory     geometry    -- PostGIS POLYGON/MULTIPOLYGON
  created_at    timestamptz

-- 유저 전체 누적 영역
user_territory
  user_id              uuid        PK  FK → users
  total_area_m2        float
  merged_territory     geometry    -- MULTIPOLYGON (전체 합집합)
  updated_at           timestamptz
```

### 인증 및 보안
- 회원가입 없음 — 앱 최초 실행 시 익명 UUID 생성, SharedPreferences에 저장
- Row Level Security:
  - `runs`: `user_id = auth.uid()` 일 때만 INSERT/UPDATE
  - `user_territory`: 동일 조건으로 쓰기 제한
  - 읽기: `user_id`만 알면 누구나 읽기 가능 (공유 링크용)

---

## 기술 스택

### Flutter 앱
| 패키지 | 용도 |
|--------|------|
| `flutter_map` | OSM 지도 렌더링 |
| `geolocator` | GPS 위치 추적 |
| `latlong2` | 좌표 계산 |
| `supabase_flutter` | DB 연동 |
| `share_plus` | 링크 공유 |

### 백엔드
| 서비스 | 용도 |
|--------|------|
| Supabase (PostgreSQL + PostGIS) | 지리 데이터 저장/연산 |
| Vercel | 공유 웹 페이지 호스팅 |

### 공유 웹 페이지
- HTML + Leaflet.js + OSM 타일
- Supabase REST API로 데이터 읽기
- 별도 프레임워크 없음 (단순 정적 페이지)

---

## 공유 링크 흐름

```
앱 → "공유" 버튼 탭
  → https://village-run.vercel.app/share/{user_id} 클립보드 복사
  → 브라우저에서 열기
  → Supabase에서 user_territory + runs 조회
  → Leaflet.js로 지도 + 영역 렌더링
  → 일별 카드 리스트 표시
```

---

## MVP 범위 (Out of Scope)

- 소셜 기능 (팔로우, 댓글)
- 멀티플레이어 / 땅 뺏기
- 푸시 알림
- 운동 통계 (심박수 등)
- 오프라인 모드
