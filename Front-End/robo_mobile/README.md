# robo_mobile

Flutter 기반 WeRobo 모바일 앱입니다.

## 주요 흐름

- 온보딩 1/2: 서비스 소개
- 온보딩 2/2: efficient frontier 차트에서 위험도와 기대수익률 preview
- 로딩: 선택한 preview point의 exact frontier selection 요청
- 결과/비교/확정: exact 선택 포트폴리오 확인 후 홈 진입

## 백엔드 연동

모바일 앱은 Railway에 배포된 FastAPI 백엔드와 통신합니다.

- 추천 API: `/api/v1/portfolios/recommendation`
- frontier preview API: `/api/v1/portfolios/frontier-preview`
- frontier selection API: `/api/v1/portfolios/frontier-selection`
- 비교 백테스트 API: `/api/v1/portfolios/comparison-backtest`

현재 온보딩 2/2 차트는 `frontier-preview` 응답을 사용해 위험도와 기대수익률 라벨을 실제 backend preview point와 맞춰서 표시합니다. 앱은 기본적으로 `sample_points=1000`으로 preview를 받아 두고, 사용자가 확정한 `selected_point_index`를 `frontier-selection`에 전달해 exact 포트폴리오를 이어받습니다.

로그인 화면은 이제 직접 회원가입/로그인도 지원합니다.

- 회원가입 API: `/api/v1/auth/signup`
- 로그인 API: `/api/v1/auth/login`
- 현재 세션 조회 API: `/api/v1/auth/me`
- 로그아웃 API: `/api/v1/auth/logout`
- 세션 저장: 앱 로컬 `shared_preferences`
- 포트폴리오 bootstrap 저장: frontier preview + exact selection 상태를 로컬에 저장

자동로그인 규칙:

1. 앱 시작 시 저장된 세션과 포트폴리오 bootstrap을 함께 복원합니다.
2. 세션이 남아 있으면 `/api/v1/auth/me`로 유효성을 확인합니다.
3. 세션과 bootstrap이 모두 유효하면 `SplashScreen` 이후 바로 `HomeShell`로 진입합니다.
4. 세션이 만료되었거나 `401`이면 저장 상태를 비우고 다시 온보딩으로 돌아갑니다.

간편로그인 버튼은 현재 placeholder이며, backend user/session 구조는 `provider` 기반으로 이미 일반화되어 있어 이후 붙일 때 direct login과 같은 세션 시스템을 재사용할 수 있습니다.

## 실행

```bash
cd "/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Front-End/robo_mobile"
flutter pub get
flutter run
```

## 웹 배포

GitHub Pages는 `main` push 시 GitHub Actions가 자동으로 Flutter 웹 빌드를 수행합니다.

- workflow: [/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/.github/workflows/robo-mobile-pages.yml](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/.github/workflows/robo-mobile-pages.yml)
- build script: [/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Front-End/robo_mobile/scripts/build_web.sh](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Front-End/robo_mobile/scripts/build_web.sh)

즉 보통은 로컬에서 먼저 `flutter build web`을 할 필요가 없습니다. push하면 Actions가 `/werobo-monorepo/` base href로 빌드해서 Pages에 올립니다.

로컬 확인이 필요하면:

```bash
cd "/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Front-End/robo_mobile"
WEB_BASE_HREF=/werobo-monorepo/ bash scripts/build_web.sh
```

## 참고

- Flutter 문서: https://docs.flutter.dev/
- 백엔드 API 명세: [/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/MOBILE_API_SPEC.md](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/MOBILE_API_SPEC.md)
