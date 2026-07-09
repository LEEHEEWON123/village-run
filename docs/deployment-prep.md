# 배포 준비 체크리스트

콘솔 계정(Play Console / Apple Developer) 만들기 **직전**까지 완료할 항목.

---

## 앱 식별 정보 (콘솔 등록 시 그대로 사용)

| 항목 | 값 |
|------|-----|
| 앱 이름 (스토어) | 내땅내밟 |
| Android 패키지명 | `com.villagerun.village_run` |
| iOS Bundle ID | `com.villagerun.village_run` *(현재 iOS는 `villageRun` — 콘솔 등록 전 통일 권장)* |
| 버전 | `1.0.0` (build `1`) |
| 공유 URL | `https://village-run-f512d.web.app/share` |
| 개인정보처리방침 | `https://village-run-f512d.web.app/privacy` |

---

## Phase 1 — 코드/인프라 (콘솔 없이 가능) ✅

- [x] 공유 웹 Firebase Hosting 배포 (`village-run-f512d`)
- [x] 개별/전체 공유 링크 동작
- [x] 개인정보처리방침 페이지 호스팅
- [x] Android 릴리스 서명 설정 스캐폴드 (`key.properties`)
- [x] `.env.example` 템플릿
- [x] 유닛 테스트 통과 (`flutter test`)
- [ ] **Android 업로드 키스토어 생성** (아래 명령 실행)
- [ ] **릴리스 빌드 성공 확인** (`flutter build appbundle`)
- [ ] **Firebase 프로젝트 통합** (`village-run-f512d` 하나로)

### Android 업로드 키스토어 생성

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storetype JKS
```

생성 후:

```bash
cp flutter/android/key.properties.example flutter/android/key.properties
# key.properties 에 경로/비밀번호 입력
```

### 릴리스 빌드

```bash
cd flutter
flutter build appbundle --release
# 산출물: build/app/outputs/bundle/release/app-release.aab
```

### Firebase 프로젝트 통합 (중요)

현재 상태가 **2개 프로젝트로 분리**되어 있음:

| 용도 | 프로젝트 ID |
|------|-------------|
| Hosting (공유 웹) | `village-run-f512d` ✅ |
| Google OAuth (`auth_service.dart`) | `village-run-f512d` ✅ |
| Flutter 앱 (`google-services.json`) | `village-run-d90a9` ⚠️ |

**콘솔 가입 전에** Firebase Console → `village-run-f512d`에서:
1. Android 앱 추가 (`com.villagerun.village_run`)
2. iOS 앱 추가 (`com.villagerun.village_run`)
3. 새 `google-services.json` / `GoogleService-Info.plist` 다운로드 후 교체
4. `flutterfire configure` 재실행

---

## Phase 2 — 스토어 등록 자료 준비 (콘솔 없이 가능)

### 공통

- [ ] 앱 설명 (짧은/긴) 초안 작성
- [ ] 스크린샷 4~8장 (1080×1920 또는 기기별)
- [ ] 앱 아이콘 512×512 PNG (이미 `assets/icon.png` 있음)
- [ ] 연락처 이메일 결정
- [ ] 개인정보처리방침 URL 확인 → https://village-run-f512d.web.app/privacy

### Google Play 전용

- [ ] 그래픽 피처 이미지 1024×500 (선택)
- [ ] 콘텐츠 등급 설문 답변 준비 (위치 수집, 로그인 있음)
- [ ] 데이터 안전성 설문 답변 준비
  - 수집: 위치(GPS), 이메일(Google 로그인), 사용자 생성 콘텐츠(러닝 경로)
  - 저장: Supabase (클라우드)
  - 공유: 링크로 러닝 기록 공개 가능

### App Store 전용

- [ ] Mac + Xcode 설치 확인
- [ ] 스크린샷 (6.7", 6.5" 등 필수 사이즈)
- [ ] 위치 사용 목적 설명 (`Info.plist`에 이미 있음)
- [ ] App Privacy 세부사항 답변 준비

---

## Phase 3 — 콘솔 계정 생성 ← **여기서부터 유료/심사**

| 플랫폼 | 비용 | 가입 |
|--------|------|------|
| Google Play Console | $25 (1회) | https://play.google.com/console |
| Apple Developer Program | ₩129,000/년 | https://developer.apple.com/programs/ |

### Play Console 가입 후

1. 앱 만들기 → 패키지명 `com.villagerun.village_run`
2. 내부 테스트 트랙에 AAB 업로드
3. Google Cloud OAuth 동의 화면 **프로덕션** 심사 요청
4. SHA-1/SHA-256 등록 (릴리스 키스토어):
   ```bash
   keytool -list -v -keystore ~/upload-keystore.jks -alias upload
   ```

### Apple Developer 가입 후

1. Certificates, Identifiers → App ID `com.villagerun.village_run` 등록
2. Xcode → Signing & Capabilities → Team 선택
3. Archive → TestFlight 업로드

---

## Phase 4 — OAuth / 백엔드 (콘솔 + Firebase 필요)

- [ ] Google Cloud Console → OAuth 동의 화면 프로덕션 전환
- [ ] Android OAuth Client (패키지명 + SHA-1)
- [ ] iOS OAuth Client (Bundle ID)
- [ ] Web OAuth Client (Supabase redirect용)
- [ ] Supabase Auth → Google Provider Client ID/Secret
- [ ] Supabase 프로덕션 URL/키 `.env` 반영

---

## 현재 미완 / 주의사항

| 항목 | 상태 |
|------|------|
| Android 릴리스 서명 | debug 키로 빌드 중 → 키스토어 생성 필요 |
| iOS/Android Bundle ID | 불일치 (`village_run` vs `villageRun`) |
| Firebase 앱 설정 | `d90a9` / `f512d` 분리 |
| 백그라운드 GPS | 미구현 (스토어 심사 시 위치 권한 설명 필요) |
| README 공유 URL | `village-run-app` → `village-run-f512d`로 업데이트 필요 |

---

## 빠른 검증 명령

```bash
cd flutter
flutter test
flutter analyze
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS (Mac + Xcode 필요)
```
