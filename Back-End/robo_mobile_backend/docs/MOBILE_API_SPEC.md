# Mobile API Spec

## 목적

이 문서는 `robo_mobile_backend`의 모바일 앱 전용 API 계약을 정리합니다.

대상 독자:

- 모바일 앱 개발자
- QA
- 백엔드 운영 담당자

이 문서는 현재 코드 기준 계약을 설명합니다. 기준 구현은 [mobile.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/api/routes/mobile.py), [request.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/api/schemas/request.py), [response.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/api/schemas/response.py) 입니다.

## 기본 규칙

- Base path: `/api/v1`
- Content-Type: `application/json`
- 인증: 현재 없음
- 날짜 형식: `YYYY-MM-DD`
- 비율 값:
  - `propensity_score`는 `0`부터 `100` 사이 점수입니다.
  - `expected_return`, `volatility`, `target_volatility`, `weight`, `return_pct`는 퍼센트 문자열이 아니라 소수 비율입니다.
  - 예: `0.12`는 `12%`를 의미합니다.

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

위험 유형 판정은 [profile_service.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/services/profile_service.py) 기준으로 동작합니다.

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
| `POST` | `/api/v1/profile/resolve` | 투자성향 판정 |
| `POST` | `/api/v1/portfolios/recommendation` | 안정형/균형형/성장형 3개 포트폴리오 추천 |
| `POST` | `/api/v1/portfolios/volatility-history` | 선택 위험유형 포트폴리오의 변동성 추이 |
| `POST` | `/api/v1/portfolios/comparison-backtest` | 유형별 비교 백테스트 |

## 1. 투자성향 판정

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

## 2. 대표 포트폴리오 추천

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

## 3. 포트폴리오 변동성 추이

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

## 4. 유형별 비교 백테스트

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

- 모바일 API는 [mobile_portfolio_service.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/services/mobile_portfolio_service.py) 를 통해 계산 코어를 호출합니다.
- 실제 계산 응답 변환은 [embedded_portfolio_engine.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/integrations/embedded_portfolio_engine.py) 가 담당합니다.
- `managed_universe`를 사용하는 경우, 실제 결과는 현재 active 관리자 유니버스 상태에 영향을 받습니다.
