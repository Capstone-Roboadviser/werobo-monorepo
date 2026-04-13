# Mobile API Spec

## 목적

이 문서는 `robo_mobile_backend`의 모바일 앱 전용 API 계약을 정리합니다.

대상 독자:

- 모바일 앱 개발자
- QA
- 백엔드 운영 담당자

이 문서는 현재 코드 기준 계약을 설명합니다. 기준 구현은 [mobile.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/api/routes/mobile.py), [request.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/api/schemas/request.py), [response.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/api/schemas/response.py) 입니다.

## 기본 규칙

- Base path: `/api/v1`
- Content-Type: `application/json`
- 인증:
  - 회원가입/로그인 자체는 인증 없이 호출합니다.
  - `GET /api/v1/auth/me`는 `Authorization: Bearer <token>` 헤더가 필요합니다.
  - `/api/v1/account/*`는 `Authorization: Bearer <token>` 헤더가 필요합니다.
- 날짜 형식: `YYYY-MM-DD`
- 비율 값:
  - `propensity_score`는 `0`부터 `100` 사이 점수입니다.
  - `expected_return`, `volatility`, `target_volatility`, `weight`, `return_pct`는 퍼센트 문자열이 아니라 소수 비율입니다.
  - 예: `0.12`는 `12%`를 의미합니다.

## Materialized Snapshot 규칙

- `data_source=managed_universe`일 때 recommendation/preview/selection API는 active 유니버스의 materialized frontier snapshot을 먼저 조회합니다.
- snapshot은 관리자 `가격 갱신 실행` 후 자동 재생성됩니다.
- snapshot이 없거나 현재 active 버전의 공통 가격 구간과 맞지 않으면, 서버는 기존 계산 경로로 fallback 합니다.

## Portfolio Account Snapshot 규칙

- 프로토타입 자산 계정은 실제 증권 계좌 연동이 아니라 서버 DB에 저장한 입금 이벤트와 종목 비중을 기준으로 계산합니다.
- 포트폴리오 확정 시 `POST /api/v1/account`로 계정을 생성하면 `portfolio_accounts`, `portfolio_cash_flows`, `portfolio_daily_snapshots`가 채워집니다.
- `POST /api/v1/account/cash-in`이 호출되면 누적 원금과 보유 수량 기준으로 일별 자산 snapshot을 다시 계산합니다.
- `managed_universe` 계정은 관리자 가격 refresh cron이 성공할 때마다 snapshot이 자동 재계산됩니다.

## Enum 값

### `risk_profile`

- `conservative`
- `balanced`
- `growth`

### `investment_horizon`

- `short`
- `medium`
- `long`

### `data_source`

- `managed_universe`
- `stock_combination_demo`

## 공통 에러 응답

모바일 API의 공통 에러 응답 형식은 아래와 같습니다.

```json
{
  "detail": "오류 상세 메시지"
}
```

상태코드:

- `400`: 입력값이 잘못되었거나 필수 조건이 부족한 경우
- `422`: 계산에 필요한 데이터가 없거나 현재 유니버스 상태로 처리가 불가능한 경우

## 투자성향 판정 규칙

위험 유형 판정은 [profile_service.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/services/profile_service.py) 기준으로 동작합니다.

우선순위:

1. `risk_profile`이 전달되면 그 값을 그대로 사용합니다.
2. 없으면 `propensity_score`로 위험 유형을 판정합니다.

점수 구간:

- `0 ~ 33.33`: `conservative`
- `33.34 ~ 66.67`: `balanced`
- `66.68 ~ 100`: `growth`

목표 변동성:

- 기본값:
  - `conservative`: `0.08`
  - `balanced`: `0.12`
  - `growth`: `0.16`
- 투자기간 보정:
  - `short`: `-0.02`
  - `medium`: `0.00`
  - `long`: `+0.02`
- 최종값은 `0.04`부터 `0.22` 사이에서 `0.02` 단위로 스냅됩니다.

## Endpoint Summary

| Method | Path | 목적 |
|---|---|---|
| `POST` | `/api/v1/auth/signup` | 이메일 회원가입 후 세션 발급 |
| `POST` | `/api/v1/auth/login` | 이메일 로그인 후 세션 발급 |
| `GET` | `/api/v1/auth/me` | 현재 로그인 세션 조회 |
| `POST` | `/api/v1/auth/logout` | 현재 로그인 세션 종료 |
| `GET` | `/api/v1/account/dashboard` | 현재 로그인 사용자의 자산 계정 요약/히스토리 조회 |
| `POST` | `/api/v1/account` | 포트폴리오 확정 시 프로토타입 자산 계정 생성 |
| `POST` | `/api/v1/account/cash-in` | 프로토타입 입금 이벤트 저장 및 스냅샷 재계산 |
| `POST` | `/api/v1/profile/resolve` | 투자성향 판정 |
| `POST` | `/api/v1/portfolios/recommendation` | 안정형/균형형/성장형 3개 포트폴리오 추천 |
| `POST` | `/api/v1/portfolios/frontier-preview` | 드래그용 efficient frontier preview 포인트 |
| `POST` | `/api/v1/portfolios/frontier-selection` | 선택한 목표 변동성에 대응하는 상세 포트폴리오 |
| `POST` | `/api/v1/portfolios/volatility-history` | 선택 위험유형 포트폴리오의 변동성 추이 |
| `POST` | `/api/v1/portfolios/comparison-backtest` | 유형별 비교 백테스트 |

## 1. 이메일 인증

### `POST /api/v1/auth/signup`

설명:

- 이메일 기반 기본 계정을 생성합니다.
- 성공하면 즉시 bearer access token을 함께 반환합니다.

요청 예시:

```json
{
  "name": "홍길동",
  "email": "investor@werobo.app",
  "password": "securepass1"
}
```

응답 예시:

```json
{
  "access_token": "token-string",
  "token_type": "bearer",
  "expires_at": "2026-05-13T08:30:00Z",
  "user": {
    "id": 1,
    "email": "investor@werobo.app",
    "name": "홍길동",
    "created_at": "2026-04-13T08:30:00Z"
  }
}
```

에러:

- `400`: 이메일 형식/비밀번호 길이/이름 길이 오류
- `409`: 이미 가입된 이메일
- `503`: `DATABASE_URL` 미설정으로 인증 저장소 미구성

### `POST /api/v1/auth/login`

설명:

- 이메일과 비밀번호를 검증하고 새 세션을 발급합니다.

요청 예시:

```json
{
  "email": "investor@werobo.app",
  "password": "securepass1"
}
```

응답 형식:

- `POST /api/v1/auth/signup`과 동일

에러:

- `400`: 입력 형식 오류
- `401`: 이메일 또는 비밀번호 불일치
- `503`: 인증 저장소 미구성

### `GET /api/v1/auth/me`

설명:

- bearer 토큰으로 현재 로그인 세션과 사용자를 조회합니다.

헤더 예시:

```text
Authorization: Bearer token-string
```

응답 예시:

```json
{
  "authenticated": true,
  "expires_at": "2026-05-13T08:30:00Z",
  "user": {
    "id": 1,
    "email": "investor@werobo.app",
    "name": "홍길동",
    "provider": "password",
    "created_at": "2026-04-13T08:30:00Z"
  }
}
```

에러:

- `401`: 헤더 없음, 형식 오류, 만료/무효 토큰
- `503`: 인증 저장소 미구성

### `POST /api/v1/auth/logout`

설명:

- 현재 bearer 토큰에 해당하는 세션을 종료합니다.
- 모바일 앱은 logout 성공 후 로컬에 저장한 세션과 bootstrap snapshot을 함께 지우는 것을 권장합니다.

응답 예시:

```json
{
  "status": "ok"
}
```

## 2. 프로토타입 자산 계정

### `GET /api/v1/account/dashboard`

설명:

- 현재 로그인 사용자의 자산 계정 상태를 조회합니다.
- 홈 화면 `현재 자산` 차트, 최근 활동, 누적 원금 표시에 필요한 데이터를 한 번에 반환합니다.

응답 예시:

```json
{
  "has_account": true,
  "summary": {
    "portfolio_code": "balanced",
    "portfolio_label": "균형형",
    "portfolio_id": "stocks-balanced-medium-0.12",
    "data_source": "managed_universe",
    "investment_horizon": "medium",
    "started_at": "2026-04-13",
    "last_snapshot_date": "2026-04-14",
    "current_value": 10325000,
    "invested_amount": 10000000,
    "profit_loss": 325000,
    "profit_loss_pct": 0.0325
  },
  "history": [
    {
      "date": "2026-04-13",
      "portfolio_value": 10000000,
      "invested_amount": 10000000,
      "profit_loss": 0,
      "profit_loss_pct": 0.0
    }
  ],
  "recent_activity": [
    {
      "type": "cash_in",
      "title": "입금",
      "date": "2026-04-14",
      "amount": 500000,
      "description": null
    }
  ]
}
```

에러:

- `401`: 헤더 없음, 형식 오류, 만료/무효 토큰
- `503`: 자산 계정 저장소 미구성

### `POST /api/v1/account`

설명:

- 포트폴리오 확정 시점의 종목 비중과 초기 입금 금액을 저장하고 프로토타입 자산 계정을 생성합니다.
- 같은 사용자에 대해 다시 호출되면 기존 계정을 교체합니다.

요청 예시:

```json
{
  "data_source": "managed_universe",
  "investment_horizon": "medium",
  "portfolio_code": "balanced",
  "portfolio_label": "균형형",
  "portfolio_id": "stocks-balanced-medium-0.12",
  "target_volatility": 0.12,
  "expected_return": 0.08,
  "volatility": 0.11,
  "sharpe_ratio": 0.72,
  "initial_cash_amount": 10000000,
  "sector_allocations": [
    {
      "asset_code": "us_growth",
      "asset_name": "미국 성장주",
      "weight": 0.3,
      "risk_contribution": 0.42
    }
  ],
  "stock_allocations": [
    {
      "ticker": "QQQ",
      "name": "Invesco QQQ Trust",
      "sector_code": "us_growth",
      "sector_name": "미국 성장주",
      "weight": 0.15
    }
  ]
}
```

응답 형식:

- `GET /api/v1/account/dashboard`와 동일

에러:

- `400`: 초기 입금 금액, 종목 비중 등 입력값 오류
- `401`: 헤더 없음, 형식 오류, 만료/무효 토큰
- `503`: 자산 계정 저장소 미구성

### `POST /api/v1/account/cash-in`

설명:

- 실제 결제/계좌 연동 없이 프로토타입 입금 이벤트를 저장합니다.
- 서버는 입금 후 전체 일별 snapshot을 다시 계산해 최신 자산 곡선을 반환합니다.

요청 예시:

```json
{
  "amount": 500000
}
```

응답 형식:

- `GET /api/v1/account/dashboard`와 동일

에러:

- `400`: 입금 금액 오류
- `401`: 헤더 없음, 형식 오류, 만료/무효 토큰
- `404`: 아직 포트폴리오 계정이 없음
- `503`: 자산 계정 저장소 미구성

## 3. 투자성향 판정

### `POST /api/v1/profile/resolve`

설명:

- 모바일 설문 결과를 서버 표준 위험 유형으로 정규화합니다.
- 앱이 이미 위험 유형을 판정한 경우 `risk_profile`만 보내도 됩니다.

요청 예시:

```json
{
  "propensity_score": 58,
  "investment_horizon": "medium",
  "data_source": "managed_universe"
}
```

응답 예시:

```json
{
  "resolved_profile": {
    "code": "balanced",
    "label": "균형형",
    "propensity_score": 58.0,
    "target_volatility": 0.12,
    "investment_horizon": "medium"
  }
}
```

## 4. 대표 포트폴리오 추천

### `POST /api/v1/portfolios/recommendation`

설명:

- 안정형, 균형형, 성장형 3개 포트폴리오를 한 번에 반환합니다.
- `recommended_portfolio_code`는 현재 사용자가 우선 노출받아야 할 유형입니다.
- 각 포트폴리오에는 자산군 비중과 종목 비중이 함께 포함됩니다.

요청 예시:

```json
{
  "propensity_score": 58,
  "investment_horizon": "medium",
  "data_source": "managed_universe"
}
```

응답 핵심 필드:

- `resolved_profile`: 사용자 판정 결과
- `recommended_portfolio_code`: 추천 유형 코드
- `portfolios`: 3개 대표 포트폴리오

포트폴리오 필드:

- `target_volatility`: 목표 변동성
- `expected_return`: 연 기대수익률
- `volatility`: 연 변동성
- `sharpe_ratio`: 샤프 비율
- `sector_allocations`: 자산군별 비중과 위험기여도
- `stock_allocations`: 종목별 비중

대표 포트폴리오 3개는 내부 efficient frontier 전체 포인트 중 대표 지점만 잘라낸 결과입니다. 모바일 UX를 단순하게 유지하기 위해 전체 frontier를 한 번에 모두 내려주지 않습니다.

## 5. 드래그용 frontier preview

### `POST /api/v1/portfolios/frontier-preview`

설명:

- 온보딩이나 비교 화면에서 efficient frontier 곡선을 가볍게 그리기 위한 preview 전용 API입니다.
- 내부적으로는 전체 frontier 포인트를 계산하지만, 응답에는 모바일 차트에 필요한 sample point만 내려줍니다.
- 대표 3개 포트폴리오에 해당하는 포인트는 sample에서 빠지지 않도록 항상 포함됩니다.
- `resolved_profile`은 추천 지점을 알려주고, `points[]`는 드래그 가능한 전체 미리보기 점 목록을 제공합니다.

요청 예시:

```json
{
  "propensity_score": 45,
  "investment_horizon": "medium",
  "data_source": "managed_universe",
  "sample_points": 61
}
```

응답 핵심 필드:

- `resolved_profile`
- `recommended_portfolio_code`
- `data_source`
- `total_point_count`: 내부에서 실제 계산한 전체 frontier 포인트 수
- `min_volatility`, `max_volatility`: 차트 축 범위 계산용 힌트
- `points[]`: 다운샘플된 preview 포인트

`points[]` 항목:

- `index`: 전체 frontier 기준 인덱스
- `volatility`: 연 변동성
- `expected_return`: 연 기대수익률
- `is_recommended`: 사용자 추천 지점 여부
- `representative_code`, `representative_label`: 대표 3개 포트폴리오와 겹칠 때만 채워짐

운영 메모:

- 모바일은 이 응답을 앱 메모리에 들고 있다가, 사용자가 점을 옮길 때마다 위험도와 기대수익률 라벨을 즉시 갱신하면 됩니다.
- 사용자가 최종 위치를 확정한 뒤에만 상세 포트폴리오 API를 호출하는 구조를 권장합니다.
- `managed_universe`에서는 가능한 한 materialized snapshot을 재사용하므로, 첫 호출 성능은 admin refresh 완료 여부에 크게 영향을 받습니다.

## 6. 선택 frontier 포트폴리오 상세

### `POST /api/v1/portfolios/frontier-selection`

설명:

- 사용자가 preview 차트에서 선택한 `target_volatility`를 기준으로, 가장 가까운 frontier 포인트의 실제 포트폴리오 상세를 반환합니다.
- 드래그 중에는 preview만 사용하고, 손을 떼거나 확정 버튼을 누를 때 이 API를 호출하는 용도입니다.
- `managed_universe` 요청에서는 저장된 per-point snapshot이 있으면 종목 비중/자산군 비중까지 재계산 없이 바로 반환합니다.

요청 예시:

```json
{
  "propensity_score": 45,
  "investment_horizon": "medium",
  "data_source": "managed_universe",
  "target_volatility": 0.108
}
```

응답 핵심 필드:

- `resolved_profile`
- `data_source`
- `requested_target_volatility`
- `selected_target_volatility`: 실제 매칭된 frontier 포인트의 변동성
- `selected_point_index`
- `representative_code`, `representative_label`: 가장 가까운 대표 포트폴리오 분류
- `portfolio`: 사용자가 선택한 상세 포트폴리오

`portfolio` 구조는 `/portfolios/recommendation`의 각 포트폴리오 항목과 동일합니다.

## 7. 포트폴리오 변동성 추이

### `POST /api/v1/portfolios/volatility-history`

설명:

- 사용자의 위험 유형에 대응하는 대표 포트폴리오를 기준으로 과거 실현 변동성 추이를 계산합니다.
- `rolling_window`는 거래일 기준 롤링 윈도우입니다.

요청 예시:

```json
{
  "risk_profile": "balanced",
  "investment_horizon": "medium",
  "data_source": "managed_universe",
  "rolling_window": 20
}
```

응답 핵심 필드:

- `portfolio_code`
- `portfolio_label`
- `rolling_window`
- `earliest_data_date`
- `latest_data_date`
- `points[]`

`points[]` 항목:

- `date`
- `volatility`

## 8. 유형별 비교 백테스트

### `POST /api/v1/portfolios/comparison-backtest`

설명:

- 안정형, 균형형, 성장형 대표 포트폴리오와 벤치마크를 같은 기간에서 비교합니다.
- 학습 구간과 테스트 구간 분할 정보가 함께 반환됩니다.

요청 예시:

```json
{
  "data_source": "managed_universe"
}
```

응답 핵심 필드:

- `train_start_date`
- `train_end_date`
- `test_start_date`
- `start_date`
- `end_date`
- `split_ratio`
- `rebalance_dates`
- `lines[]`

`lines[]` 항목:

- `key`
- `label`
- `color`
- `style`
- `points[]`

## 구현 메모

- 모바일 API는 [mobile_portfolio_service.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/services/mobile_portfolio_service.py) 를 통해 계산 코어를 호출합니다.
- 실제 계산 응답 변환은 [embedded_portfolio_engine.py](/Users/yoonseungjae/Documents/code/RoboAdviser/werobo-monorepo/Back-End/robo_mobile_backend/mobile_backend/integrations/embedded_portfolio_engine.py) 가 담당합니다.
- `managed_universe`를 사용하는 경우, 실제 결과는 현재 active 관리자 유니버스 상태에 영향을 받습니다.
- recommendation, frontier preview, frontier selection은 같은 계산 컨텍스트를 기반으로 보기 때문에, 같은 `data_source`와 같은 시점의 데이터에서는 서로 일관된 위험도/기대수익률 축을 유지해야 합니다.
