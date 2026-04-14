# Robo Mobile Backend

모바일 앱 전용으로 분리한 FastAPI 백엔드 프로젝트입니다.

이 프로젝트의 목표는 두 가지입니다.

1. 웹 UI와 관리자 콘솔 책임을 완전히 분리한 모바일 전용 API를 제공한다.
2. 모바일 백엔드 프로젝트 안에 계산 코어를 직접 포함해 독립적으로 배포할 수 있게 한다.

## 현재 상태

현재 이 프로젝트는 아래를 제공합니다.

- 모바일 전용 FastAPI 앱 골격
- Swagger/OpenAPI 문서가 정리된 모바일 API 라우트
- 투자성향 판정 API
- 이메일 회원가입 / 로그인 API
- 인증 사용자용 프로토타입 자산 계정 / 입금 API
- 3개 대표 포트폴리오 추천 API
- full frontier까지 요청 가능한 efficient frontier preview API
- `point_index` 기반 exact frontier selection API
- 대표 분류 또는 exact 종목 비중 기준 포트폴리오 변동성 추이 API
- 포트폴리오 유형별 성과 비교 API
- 프로젝트 내부에 포함된 계산 코어와 모바일 응답 adapter
- 가벼운 관리자 웹에서 종목 검색/등록과 자산군별 role 지정

중요:

- 계산 코어는 프로젝트 루트의 [`app`](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/app) 패키지에 포함되어 있습니다.
- 이 `app` 패키지는 모바일 백엔드가 직접 보유하는 내장 계산 코어입니다.
- 모바일 API는 [`mobile_backend`](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend) 패키지에서 별도 계약을 유지합니다.

## 프로젝트 구조

```text
robo_mobile_backend/
  mobile_backend/
    api/
      routes/
      schemas/
    core/
    domain/
    integrations/
    services/
    main.py
  docs/
  requirements.txt
  railway.json
```

## 문서

- [모바일 API 명세](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/MOBILE_API_SPEC.md)
- [관리자 운영 문서](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/ADMIN_OPERATIONS.md)
- [아키텍처 개요](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/ARCHITECTURE.md)
- [기대수익률/배당 파이프라인](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/docs/EXPECTED_RETURN_PIPELINE.md)

## 주요 엔드포인트

- `GET /health`
- `GET /admin`
- `GET /admin/api/universe/status`
- `GET /admin/api/universe/asset-role-config`
- `GET /admin/api/universe/versions`
- `POST /admin/api/universe/versions`
- `POST /admin/api/universe/versions/{version_id}/activate`
- `POST /admin/api/prices/refresh`
- `POST /admin/api/prices/refresh/active`
- `GET /admin/api/universe/readiness`
- `POST /api/v1/profile/resolve`
- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/account/dashboard`
- `POST /api/v1/account`
- `POST /api/v1/account/cash-in`
- `POST /api/v1/portfolios/recommendation`
- `POST /api/v1/portfolios/frontier-preview`
- `POST /api/v1/portfolios/frontier-selection`
- `POST /api/v1/portfolios/volatility-history`
- `POST /api/v1/portfolios/comparison-backtest`

## 이메일 인증

모바일 앱은 이제 소셜 로그인과 별도로 직접 회원가입/로그인을 지원합니다.

- 저장소: 기존 `DATABASE_URL` Postgres를 재사용
- 사용자 테이블: `auth_users`
- 세션 테이블: `auth_sessions`
- 비밀번호 저장 방식: `PBKDF2-HMAC-SHA256` + 개별 salt
- 세션 토큰: 30일 유효 bearer token

현재 제공 엔드포인트:

1. `POST /api/v1/auth/signup`
   이름, 이메일, 비밀번호로 계정을 만들고 즉시 로그인 세션을 발급합니다.
2. `POST /api/v1/auth/login`
   이메일과 비밀번호를 검증하고 로그인 세션을 발급합니다.
3. `GET /api/v1/auth/me`
   `Authorization: Bearer <token>` 헤더로 현재 세션과 사용자 정보를 조회합니다.
4. `POST /api/v1/auth/logout`
   현재 bearer 세션을 revoke 합니다.

모바일 앱은 로그인 성공 시 access token과 사용자 정보를 로컬에 저장해 재실행 후에도 세션을 유지합니다.

추가 구조:

- `auth_provider` / `provider_user_id` 컬럼을 미리 두어 이후 Google, Kakao, Naver, Apple 계정을 바로 같은 테이블에 수용할 수 있습니다.
- 현재 직접 회원가입 계정은 `provider=password`로 저장됩니다.
- social 계정은 추후 `password_salt` / `password_hash` 없이 provider identity 기반으로 같은 세션 시스템을 재사용할 수 있게 설계되어 있습니다.

## 프로토타입 자산 계정

모바일 앱은 실제 증권 계좌 연동 대신, 프로토타입 단계에서는 앱 내부 입금 이벤트를 DB에 저장하는 방식으로 현재 자산을 추적합니다.

- 계정 테이블: `portfolio_accounts`
- 입금 이벤트 테이블: `portfolio_cash_flows`
- 일별 스냅샷 테이블: `portfolio_daily_snapshots`

현재 제공 엔드포인트:

1. `GET /api/v1/account/dashboard`
   현재 로그인 사용자의 자산 요약, 일별 스냅샷, 최근 활동을 반환합니다.
2. `POST /api/v1/account`
   포트폴리오 확정 시점의 종목 비중과 초기 입금액을 저장하고 자산 계정을 생성합니다.
3. `POST /api/v1/account/cash-in`
   실제 계좌 연동 없이 프로토타입 입금 이벤트를 저장하고 일별 스냅샷을 다시 계산합니다.

동작 규칙:

- 초기 자산 계정 생성 시 기본 원금과 포트폴리오 종목 비중이 저장됩니다.
- 자산 스냅샷은 공용 리밸런싱 엔진을 사용해 계산되며, 분기말 정기 리밸런싱과 일일 10% drift guard를 함께 반영합니다.
- `cash-in`이 발생하면 누적 원금과 리밸런싱 정책을 함께 반영해 일별 스냅샷이 다시 계산됩니다.
- 홈 화면 `현재 자산` 차트와 `최근 활동`은 이 스냅샷/이벤트를 우선 사용합니다.
- 로그인하지 않은 사용자는 기존 목업 fallback을 사용합니다.

## 관리자 refresh와 snapshot

`POST /admin/api/prices/refresh`는 이제 가격 데이터만 적재하는 것으로 끝나지 않습니다.

성공 또는 부분 성공으로 끝나면 같은 요청 안에서 아래 작업이 이어집니다.

1. active 유니버스의 공통 가격 구간 계산
2. refresh 대상 티커의 배당수익률 추정치 저장
3. `managed_universe` 기준 efficient frontier 재계산
4. `short`, `medium`, `long` horizon별 materialized frontier snapshot 저장
5. `managed_universe` comparison backtest snapshot 저장
6. `managed_universe`를 사용하는 사용자 포트폴리오 계정의 일별 자산 snapshot 재계산

그 결과 모바일 API의 아래 엔드포인트는 `managed_universe` 요청 시 저장된 snapshot을 우선 읽고, 없을 때만 기존 계산 경로로 fallback 합니다.
즉 응답 기준 시점은 마지막 성공한 admin refresh 시점과 일치할 수 있습니다.

- `POST /api/v1/portfolios/recommendation`
- `POST /api/v1/portfolios/frontier-preview`
- `POST /api/v1/portfolios/frontier-selection`
- `POST /api/v1/portfolios/comparison-backtest`

배당 반영 role은 request 시점에 외부 배당 데이터를 바로 조회하지 않습니다.
admin refresh가 저장한 ticker별 dividend yield estimate를 우선 사용하고,
저장값이 없을 때만 `ENABLE_LIVE_MARKET_DATA_FETCH=true` 환경에서 live fallback이 가능합니다.

자동 주기 갱신이 필요하면 `POST /admin/api/prices/refresh/active`를 사용하면 됩니다.

- 대상: 현재 active 유니버스 + `managed_universe` 사용자 계정이 이미 보유 중인 티커
- 인증: `X-Admin-Secret` 헤더
- 서버 설정: `ADMIN_REFRESH_SECRET` 환경변수
- 권장 호출 주기: 하루 1번
- 후속 작업: dividend yield estimate 갱신 + frontier snapshot 재생성 + comparison backtest snapshot 재생성 + `managed_universe` 사용자 자산 snapshot 재계산

현재 market refresh는 `yfinance`의 일별 가격 데이터(`date`, `adjusted_close`)와
배당 지급 이력을 함께 사용합니다.

### Railway cron 권장 설정

Railway에서는 웹 서비스와 별도로 cron 서비스를 하나 더 두는 편이 안전합니다.

- Source Repo: 같은 `werobo-monorepo`
- Root Directory: `/Back-End/robo_mobile_backend`
- Start Command: `python scripts/run_active_refresh.py`

cron 서비스 변수:

- `BACKEND_BASE_URL=https://robomobilebackend-production.up.railway.app`
- `ADMIN_REFRESH_SECRET=<웹 서비스와 동일한 secret>`
- `REFRESH_MODE=incremental`
- `FULL_LOOKBACK_YEARS=5`

권장 스케줄:

- 하루 1번
- 미국 종가 반영 이후 한국시간 오전 7~9시대
- Railway cron은 UTC 기준
- 예시: 한국시간 오전 8시는 UTC 전날 23시이므로 `0 23 * * *`

cron이 성공하면 아래가 한 번에 갱신됩니다.

1. active 유니버스 가격 데이터 + `managed_universe` 사용자 보유 티커 가격 데이터
2. refresh 대상 ticker의 dividend yield estimate
3. `managed_universe` materialized frontier snapshot
4. `managed_universe` comparison backtest snapshot
5. `managed_universe` 사용자 포트폴리오 계정의 `portfolio_daily_snapshots`

## 실행 방법

```bash
cd "/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn mobile_backend.main:app --reload
```

접속:

- API 문서: `http://127.0.0.1:8000/docs`
- 헬스체크: `http://127.0.0.1:8000/health`
- 관리자 웹: `http://127.0.0.1:8000/admin`

## 계산 코어 동작 방식

현재 [`embedded_portfolio_engine.py`](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/integrations/embedded_portfolio_engine.py)는 프로젝트 내부의 [`app`](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/app) 계산 패키지를 읽어 모바일 응답 형태로 재조립합니다.

이 구조의 장점:

- 모바일 API와 계산 코어가 같은 프로젝트 안에 존재함
- 계산 코어를 외부 프로젝트 없이 독립적으로 유지할 수 있음
- 이후 계산 코어 리팩터링도 같은 저장소 안에서 진행할 수 있음

주의할 점:

- 현재 계산 패키지는 모바일 백엔드 안에 포함돼 있지만, 내부 네임스페이스 정리는 계속 진행할 수 있습니다.

## 모바일 차트 흐름

현재 모바일 투자 흐름은 아래처럼 나뉩니다.

1. `/api/v1/portfolios/frontier-preview`
   현재 모바일 온보딩은 기본적으로 이 endpoint를 먼저 호출합니다. 앱은 `sample_points=301`로 preview를 받아 efficient frontier 점들을 메모리에 들고, 드래그 중 위험도/기대수익률 라벨을 즉시 갱신합니다.
2. `/api/v1/portfolios/frontier-selection`
   사용자가 확정한 `selected_point_index`를 그대로 넘겨 exact 포트폴리오를 가져옵니다. 이 시점부터 결과/비교/확정/계정 생성은 선택된 exact 포트폴리오를 기준으로 이어집니다.
3. `/api/v1/portfolios/recommendation`
   대표 3종 요약이 필요할 때 사용할 수 있는 보조 endpoint로 유지합니다.

이 구조를 쓰는 이유:

- 모바일 초기 로딩 payload를 작게 유지할 수 있음
- efficient frontier 전체를 내부적으로 계산하되, 앱이 필요하면 거의 full frontier에 가까운 점 집합도 요청할 수 있음
- 위험도/기대수익률 라벨과 실제 선택 포트폴리오를 같은 frontier point 기반으로 정확히 맞출 수 있음
- 관리자 refresh 이후에는 materialized frontier snapshot과 comparison backtest snapshot을 재사용하므로 동일 유니버스 요청의 첫 응답 지연을 줄일 수 있음

## 다음 권장 작업

1. 모바일 앱의 투자성향 설문 규칙 확정
2. 소셜 로그인 provider 연결
3. 내부 `app` 계산 패키지를 `mobile_backend` 네임스페이스로 점진 통합
4. 모바일 전용 OpenAPI 응답 예시와 에러 모델 보강
