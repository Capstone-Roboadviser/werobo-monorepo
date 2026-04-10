# robo_mobile

Flutter 기반 WeRobo 모바일 앱입니다.

## 주요 흐름

- 온보딩 1/2: 서비스 소개
- 온보딩 2/2: efficient frontier 차트에서 위험도와 기대수익률 preview
- 로딩: 대표 포트폴리오 추천 요청
- 결과/비교/확정: 추천 포트폴리오 확인 후 홈 진입

## 백엔드 연동

모바일 앱은 Railway에 배포된 FastAPI 백엔드와 통신합니다.

- 추천 API: `/api/v1/portfolios/recommendation`
- frontier preview API: `/api/v1/portfolios/frontier-preview`
- frontier selection API: `/api/v1/portfolios/frontier-selection`
- 비교 백테스트 API: `/api/v1/portfolios/comparison-backtest`

현재 온보딩 2/2 차트는 `frontier-preview` 응답을 사용해 위험도와 기대수익률 라벨을 실제 backend preview point와 맞춰서 표시합니다.

## 실행

```bash
cd "/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Front-End/robo_mobile"
flutter pub get
flutter run
```

## 참고

- Flutter 문서: https://docs.flutter.dev/
- 백엔드 API 명세: [/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/MOBILE_API_SPEC.md](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/MOBILE_API_SPEC.md)
