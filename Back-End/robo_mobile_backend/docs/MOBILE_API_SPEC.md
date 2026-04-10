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
- 인증: 현재 없음
- 날짜 형식: `YYYY-MM-DD`
- 비율 값:
  - `propensity_score`는 `0`부터 `100` 사이 점수입니다.
  - `expected_return`, `volatility`, `target_volatility`, `weight`, `return_pct`는 퍼센트 문자열이 아니라 소수 비율입니다.
  - 예: `0.12`는 `12%`를 의미합니다.

## Materialized Snapshot 규칙

- `data_source=managed_universe`일 때 recommendation/preview/selection API는 active 유니버스의 materialized frontier snapshot을 먼저 조회합니다.
- snapshot은 관리자 `가격 갱신 실행` 후 자동 재생성됩니다.
- snapshot이 없거나 현재 active 버전의 공통 가격 구간과 맞지 않으면, 서버는 기존 계산 경로로 fallback 합니다.

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
| `POST` | `/api/v1/profile/resolve` | 투자성향 판정 |
| `POST` | `/api/v1/portfolios/recommendation` | 안정형/균형형/성장형 3개 포트폴리오 추천 |
| `POST` | `/api/v1/portfolios/frontier-preview` | 드래그용 efficient frontier preview 포인트 |
| `POST` | `/api/v1/portfolios/frontier-selection` | 선택한 목표 변동성에 대응하는 상세 포트폴리오 |
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

대표 포트폴리오 3개는 내부 efficient frontier 전체 포인트 중 대표 지점만 잘라낸 결과입니다. 모바일 UX를 단순하게 유지하기 위해 전체 frontier를 한 번에 모두 내려주지 않습니다.

## 3. 드래그용 frontier preview

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

## 4. 선택 frontier 포트폴리오 상세

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

## 5. 포트폴리오 변동성 추이

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

## 6. 유형별 비교 백테스트

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
