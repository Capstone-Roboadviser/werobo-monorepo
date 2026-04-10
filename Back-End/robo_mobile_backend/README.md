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
- 3개 대표 포트폴리오 추천 API
- efficient frontier preview API
- 선택 frontier 포트폴리오 상세 API
- 포트폴리오 변동성 추이 API
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
- `POST /api/v1/portfolios/recommendation`
- `POST /api/v1/portfolios/frontier-preview`
- `POST /api/v1/portfolios/frontier-selection`
- `POST /api/v1/portfolios/volatility-history`
- `POST /api/v1/portfolios/comparison-backtest`

## 관리자 refresh와 snapshot

`POST /admin/api/prices/refresh`는 이제 가격 데이터만 적재하는 것으로 끝나지 않습니다.

성공 또는 부분 성공으로 끝나면 같은 요청 안에서 아래 작업이 이어집니다.

1. active 유니버스의 공통 가격 구간 계산
2. `managed_universe` 기준 efficient frontier 재계산
3. `short`, `medium`, `long` horizon별 materialized frontier snapshot 저장

그 결과 모바일 API의 아래 엔드포인트는 `managed_universe` 요청 시 저장된 snapshot을 우선 읽고, 없을 때만 기존 계산 경로로 fallback 합니다.

- `POST /api/v1/portfolios/recommendation`
- `POST /api/v1/portfolios/frontier-preview`
- `POST /api/v1/portfolios/frontier-selection`

자동 주기 갱신이 필요하면 `POST /admin/api/prices/refresh/active`를 사용하면 됩니다.

- 대상: 현재 active 유니버스만
- 인증: `X-Admin-Secret` 헤더
- 서버 설정: `ADMIN_REFRESH_SECRET` 환경변수
- 권장 호출 주기: 하루 1번

현재 가격 데이터는 `yfinance`의 일별 가격 데이터(`date`, `adjusted_close`)를 사용합니다.

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

현재 모바일 투자 흐름은 두 단계로 나뉩니다.

1. `/api/v1/portfolios/recommendation`
   초기 진입 시 안정형, 균형형, 성장형 3개 대표 포트폴리오를 빠르게 보여줍니다.
2. `/api/v1/portfolios/frontier-preview` + `/api/v1/portfolios/frontier-selection`
   드래그 기반 차트 UX에서는 preview 포인트만 먼저 내려주고, 사용자가 최종 위치를 확정한 뒤 상세 포트폴리오를 가져오는 구조를 지원합니다.

이 구조를 쓰는 이유:

- 모바일 초기 로딩 payload를 작게 유지할 수 있음
- efficient frontier 전체를 내부적으로 계산하되, 화면에는 필요한 점만 샘플링해서 전달할 수 있음
- 위험도/기대수익률 라벨과 실제 선택 포트폴리오를 같은 frontier 기반으로 맞출 수 있음
- 관리자 refresh 이후에는 materialized frontier snapshot을 재사용하므로 동일 유니버스 요청의 첫 응답 지연을 줄일 수 있음

## 다음 권장 작업

1. 모바일 앱의 투자성향 설문 규칙 확정
2. 사용자 인증 / 저장 API 추가
3. 내부 `app` 계산 패키지를 `mobile_backend` 네임스페이스로 점진 통합
4. 모바일 전용 OpenAPI 응답 예시와 에러 모델 보강
