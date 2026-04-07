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
- 포트폴리오 변동성 추이 API
- 포트폴리오 유형별 성과 비교 API
- 프로젝트 내부에 포함된 계산 코어와 모바일 응답 adapter
- 가벼운 관리자 웹에서 종목 검색/등록과 자산군별 role 지정

중요:

- 계산 코어는 프로젝트 루트의 [`app`](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/app) 패키지에 포함되어 있습니다.
- 이 `app` 패키지는 기존 `fastapi-demo`의 계산 관련 계층을 모바일 백엔드 안으로 이관한 것입니다.
- 모바일 API는 [`mobile_backend`](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend) 패키지에서 별도 계약을 유지합니다.

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

- [모바일 API 명세](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/docs/MOBILE_API_SPEC.md)
- [관리자 운영 문서](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/docs/ADMIN_OPERATIONS.md)
- [아키텍처 개요](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/docs/ARCHITECTURE.md)

## 주요 엔드포인트

- `GET /health`
- `GET /admin`
- `GET /admin/api/universe/status`
- `GET /admin/api/universe/asset-role-config`
- `GET /admin/api/universe/versions`
- `POST /admin/api/universe/versions`
- `POST /admin/api/universe/versions/{version_id}/activate`
- `POST /admin/api/prices/refresh`
- `GET /admin/api/universe/readiness`
- `POST /api/v1/profile/resolve`
- `POST /api/v1/portfolios/recommendation`
- `POST /api/v1/portfolios/volatility-history`
- `POST /api/v1/portfolios/comparison-backtest`

## 실행 방법

```bash
cd "/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend"
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

현재 [`legacy_fastapi_demo.py`](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/integrations/legacy_fastapi_demo.py)는 프로젝트 내부의 [`app`](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/app) 계산 패키지를 읽어 모바일 응답 형태로 재조립합니다.

이 구조의 장점:

- 모바일 API와 계산 코어가 같은 프로젝트 안에 존재함
- 기존 계산 검증 자산을 빠르게 재사용할 수 있음
- 이후 계산 코어 리팩터링도 같은 저장소 안에서 진행할 수 있음

주의할 점:

- 현재 계산 패키지의 일부 모듈/이름은 기존 구조를 유지하고 있습니다.
- 즉 외부 의존성은 제거됐지만, 내부 구조 정리는 아직 더 진행할 수 있습니다.

## 다음 권장 작업

1. 모바일 앱의 투자성향 설문 규칙 확정
2. 사용자 인증 / 저장 API 추가
3. 내부 `app` 계산 패키지를 `mobile_backend` 네임스페이스로 점진 통합
4. 모바일 전용 OpenAPI 응답 예시와 에러 모델 보강
