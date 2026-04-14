# Architecture

## 목표

`robo_mobile_backend`는 모바일 앱이 호출할 API만 책임지는 별도 백엔드입니다.

## 현재 구조

`mobile app -> robo_mobile_backend API -> internal adapter -> embedded calculation core`

## 의도된 최종 구조

`mobile app -> robo_mobile_backend API -> mobile backend service/core/data`

## 계층

- `api`
  - 모바일 계약에 맞는 request/response와 라우트
- `services`
  - 투자성향 판정과 모바일 응답 orchestration
- `integrations`
  - 내부 계산 코어를 모바일 응답으로 재조립하는 adapter
- `app`
  - 모바일 백엔드 안으로 이관한 계산 코어
  - `core / data / domain / engine / services / api(routes/portfolio helper)` 포함
- `domain`
  - 모바일 백엔드에서 사용하는 enum과 도메인 타입
- `core`
  - 설정, 앱 메타데이터

## Managed Market Data Pipeline

`admin refresh -> stored prices + stored dividend estimates -> snapshots -> mobile runtime reuse`

- 가격과 배당수익률 추정치는 refresh 시점에 적재한다.
- 기대수익률 계산은 저장된 dividend estimate를 우선 사용한다.
- request-path live fetch는 기본 경로가 아니라 fallback/debug 경로다.

이 구조는 role 의미를 유지하면서 모바일 API latency를 안정적으로 관리하기 위한 것이다.

## 마이그레이션 우선순위

1. `app` 계산 코어를 `mobile_backend` 네임스페이스로 재배치
2. 모바일 응답용 orchestration과 계산용 orchestration 분리
3. 비교/변동성 계산 helper를 route 모듈 밖으로 분리
4. 사용자 저장 / 인증 / 이력 모델 추가
