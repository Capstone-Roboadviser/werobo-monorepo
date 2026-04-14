# Admin Operations

## 목적

이 문서는 `/admin` 웹과 `/admin/api/*` 운영 API의 사용 목적과 운영 절차를 정리합니다.

기준 구현:

- 관리자 웹: [admin_web.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/admin_web.py)
- 관리자 API: [admin.py](/Users/yoonseungjae/Documents/code/RoboAdviser/robo_mobile_backend/mobile_backend/api/routes/admin.py)

## 관리자 웹이 담당하는 일

현재 관리자 웹은 아래 작업을 위한 가벼운 운영 콘솔입니다.

- 승인 종목 검색 및 등록
- 유니버스 버전 생성
- 자산군별 role 지정
- active 유니버스 전환
- 가격 데이터 갱신
- 사용자 포트폴리오 계정 snapshot 일괄 재계산
- readiness 점검

## 사전 조건

- `DATABASE_URL`이 설정되어 있어야 합니다.
- 가격 적재와 티커 검색은 외부 데이터 소스 접근이 가능한 런타임 환경에서 동작해야 합니다.
- 현재 관리자 인증은 아직 없습니다.

## 핵심 개념

### 1. 유니버스 버전

유니버스 버전은 특정 시점의 승인 종목 목록과 자산군별 role 설정을 함께 스냅샷으로 저장한 단위입니다.

버전 안에 포함되는 것:

- `instruments`
- `asset_roles`

### 2. Active 버전

모바일 API는 항상 현재 active 유니버스 버전을 기준으로 계산합니다.

즉 운영 절차는 보통 아래 순서입니다.

1. 새 버전 생성
2. 가격 갱신
3. readiness 확인
4. 이상 없으면 active 전환

### 3. 자산군 role

자산군 role은 자산군 후보 종목을 계산 입력으로 어떻게 해석할지 정하는 규칙입니다.

현재 지원 role:

- `single_representative`
  - 후보 종목 중 대표 1개를 선택
- `equal_weight_dividend_basket`
  - 후보 종목 전체를 optimizer 후보로 사용
  - 최종 종목 비중은 optimizer가 결정
  - refresh가 저장한 ticker별 dividend yield estimate를 기대수익률 overlay로 가산
- `fixed_five_percent_equal_weight`
  - 후보 종목 전체를 사용하되 해당 자산군 총합을 항상 5%로 고정
  - 자산군 내부 종목은 동일비중으로 분할

호환 규칙:

- 과거 버전이나 외부 요청이 `equal_weight_basket`을 보내더라도 서버는 내부적으로 `equal_weight_dividend_basket`으로 정규화합니다.
- 관리자 UI와 현재 문서에서는 중복을 피하기 위해 `equal_weight_dividend_basket`만 노출합니다.

현재 구현 기준으로 role은 버전별 snapshot으로 저장됩니다.

즉:

- `2026-04 버전`과 `2026-05 버전`은 같은 종목을 써도 서로 다른 role 구성을 가질 수 있습니다.

## 운영 API Summary

| Method | Path | 목적 |
|---|---|---|
| `GET` | `/admin` | 관리자 웹 UI |
| `GET` | `/admin/api/universe/status` | 현재 active 상태 요약 |
| `GET` | `/admin/api/universe/asset-role-config` | 자산군/role 드롭다운용 카탈로그 |
| `GET` | `/admin/api/universe/versions` | 유니버스 버전 목록 |
| `GET` | `/admin/api/universe/versions/{version_id}` | 버전 상세 |
| `POST` | `/admin/api/universe/versions` | 새 버전 생성 |
| `DELETE` | `/admin/api/universe/versions/{version_id}` | 버전 삭제 |
| `POST` | `/admin/api/universe/versions/{version_id}/activate` | active 전환 |
| `POST` | `/admin/api/prices/refresh` | 가격 갱신 |
| `POST` | `/admin/api/prices/refresh/active` | active 유니버스 주기 갱신 |
| `GET` | `/admin/api/universe/readiness` | 시뮬레이션 준비 상태 |
| `GET` | `/admin/api/tickers/search` | 종목명/키워드 검색 |
| `GET` | `/admin/api/tickers/lookup` | 티커 자동채움 |

## 주요 운영 절차

## 1. 새 유니버스 버전 생성

입력 항목:

- `version_name`
- `notes`
- `activate`
- `asset_roles[]`
- `instruments[]`

`asset_roles[]` 예시:

```json
[
  {
    "asset_code": "us_growth",
    "role_key": "single_representative"
  },
  {
    "asset_code": "gold",
    "role_key": "equal_weight_dividend_basket"
  },
  {
    "asset_code": "infra_bond",
    "role_key": "fixed_five_percent_equal_weight"
  }
]
```

`instruments[]` 예시:

```json
[
  {
    "ticker": "QQQ",
    "name": "Invesco QQQ Trust",
    "sector_code": "us_growth",
    "sector_name": "미국 성장주",
    "market": "NASDAQ",
    "currency": "USD",
    "base_weight": null
  }
]
```

운영 주의:

- 종목이 없는 빈 유니버스는 저장할 수 없습니다.
- role 미지정 자산군은 기본 카탈로그의 기본 role을 따릅니다.
- `equal_weight_dividend_basket`은 refresh가 저장한 dividend yield estimate를 사용하므로, 가격 refresh가 최근 성공한 상태에서 가장 잘 동작합니다.
- request 시점 live fallback은 `ENABLE_LIVE_MARKET_DATA_FETCH=true`일 때만 허용됩니다.

## 2. 가격 데이터 갱신

### `POST /admin/api/prices/refresh`

입력:

- `version_id`
  - 없으면 active 버전 사용
- `refresh_mode`
  - `incremental`
  - `full`
- `full_lookback_years`

운영 규칙:

- 가격 데이터는 버전별 테이블이 아니라 전역 가격 테이블에 누적 저장됩니다.
- 계산은 버전별 종목 집합의 공통 가격 구간만 사용합니다.
- refresh가 `success` 또는 `partial_success`로 끝나면 같은 요청 안에서 `managed_universe`용 frontier snapshot도 다시 생성합니다.
- 같은 요청 안에서 `managed_universe`용 comparison backtest snapshot도 다시 생성합니다.
- 같은 요청 안에서 `managed_universe`를 사용하는 사용자 포트폴리오 계정 snapshot도 다시 계산합니다.
- 같은 요청 안에서 refresh 대상 ticker의 dividend yield estimate도 함께 갱신합니다.
- frontier snapshot은 `short`, `medium`, `long` horizon별로 저장되며, 모바일 recommendation/preview/selection API가 우선 재사용합니다.
- comparison backtest snapshot은 horizon 없이 버전별 1개로 저장되며, 모바일 `comparison-backtest` API가 우선 재사용합니다.
- 현재 가격 수집 단위는 일봉입니다. 저장 컬럼은 `date`, `adjusted_close`입니다.
- 배당수익률 추정치는 ticker 단위로 별도 저장하며, expectation overlay 계산이 이 값을 우선 재사용합니다.

응답 추가 필드:

- `frontier_snapshot.status`
- `frontier_snapshot.snapshot_count`
- `frontier_snapshot.horizons`
- `frontier_snapshot.failed_horizons`
- `frontier_snapshot.message`
- `comparison_backtest_snapshot.status`
- `comparison_backtest_snapshot.snapshot_count`
- `comparison_backtest_snapshot.line_count`
- `comparison_backtest_snapshot.message`
- `account_snapshot_refresh.status`
- `account_snapshot_refresh.account_count`
- `account_snapshot_refresh.success_count`
- `account_snapshot_refresh.failure_count`
- `account_snapshot_refresh.failed_user_ids`
- `account_snapshot_refresh.message`

수동 실행 예시:

```bash
curl -X POST "http://127.0.0.1:8000/admin/api/prices/refresh" \
  -H "Content-Type: application/json" \
  -d '{
    "version_id": 12,
    "refresh_mode": "incremental",
    "full_lookback_years": 5
  }'
```

운영 해석:

- `version_id`를 주면 그 버전을 기준으로 refresh합니다.
- `version_id`를 생략하면 현재 active 버전을 기준으로 refresh합니다.
- 일반 운영은 `incremental`, 이력 재적재나 복구 작업만 `full`을 권장합니다.

### `POST /admin/api/prices/refresh/active`

용도:

- Railway cron/job 등 외부 스케줄러가 현재 active 유니버스를 주기적으로 갱신할 때 사용합니다.

보안:

- 서버 환경변수 `ADMIN_REFRESH_SECRET`가 설정되어 있어야 합니다.
- 요청 헤더 `X-Admin-Secret`이 그 값과 일치해야 합니다.

입력:

- `refresh_mode`
  - `incremental`
  - `full`
- `full_lookback_years`

운영 권장:

- 일반 운영은 `incremental`
- 장기 백필이나 문제 복구 시에만 `full`
- 미국 시장 종가 반영 이후 하루 1회 호출
- 호출 성공 시 active 유니버스 종목뿐 아니라 `managed_universe` 사용자 계정이 이미 보유 중인 티커도 함께 최신화됨
- 호출 성공 시 `managed_universe` comparison backtest snapshot과 사용자 자산 snapshot도 함께 최신화됨

cron/외부 job 직접 호출 예시:

```bash
curl -X POST "https://<your-backend>/admin/api/prices/refresh/active" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Secret: ${ADMIN_REFRESH_SECRET}" \
  -d '{
    "refresh_mode": "incremental",
    "full_lookback_years": 5
  }'
```

내장 스크립트 예시:

```bash
cd Back-End/robo_mobile_backend
BACKEND_BASE_URL="https://robomobilebackend-production.up.railway.app" \
ADMIN_REFRESH_SECRET="<same-secret>" \
REFRESH_MODE="incremental" \
FULL_LOOKBACK_YEARS="5" \
python scripts/run_active_refresh.py
```

### 포트폴리오 계정 snapshot 자동 갱신 규칙

- 대상: `portfolio_accounts.data_source = managed_universe` 인 계정
- 트리거: `POST /admin/api/prices/refresh`, `POST /admin/api/prices/refresh/active`
- 방식: 각 계정의 저장된 `stock_weights`와 `portfolio_cash_flows`를 기준으로 `portfolio_daily_snapshots` 전체를 재생성
- 목적: 모바일 홈의 `현재 자산` 차트와 최근 활동이 일일 가격 갱신을 바로 반영하도록 유지

주의:

- `stock_combination_demo` 계정은 관리자 가격 refresh 대상이 아니므로 이 자동 배치에 포함되지 않습니다.
- `managed_universe` 계정은 현재 active 유니버스에 없는 예전 보유 티커라도 저장된 `stock_weights`에 포함돼 있으면 refresh 대상에 계속 포함됩니다.
- 계정 snapshot 계산은 가격 refresh 이후 수행되므로, 같은 응답 안에서 성공/실패 상태를 함께 확인할 수 있습니다.

## 3. Readiness 확인

### `GET /admin/api/universe/readiness`

이 API는 아래를 확인합니다.

- active 버전 존재 여부
- 종목 등록 여부
- 가격 데이터 적재 여부
- 자산군별 최소 종목 수 충족 여부
- 짧은 이력 종목 존재 여부
- 실제 최적화 가능한 공통 수익률 row 수

주요 필드:

- `ready`
- `summary`
- `issues`
- `sector_checks`
- `short_history_instruments`
- `price_window`

## 4. 티커 검색과 자동채움

### `GET /admin/api/tickers/search`

용도:

- 종목명이나 키워드를 기준으로 후보 티커 목록을 찾습니다.

파라미터:

- `query`
- `max_results`

### `GET /admin/api/tickers/lookup`

용도:

- 정확한 티커를 기준으로 종목명, 시장, 통화, 거래소 정보를 자동채움합니다.

파라미터:

- `ticker`

## 공통 에러 응답

형식:

```json
{
  "detail": "오류 상세 메시지"
}
```

주요 상태코드:

- `404`: 요청한 유니버스 버전을 찾을 수 없음
- `422`: 현재 DB 상태, 데이터 부족, 운영 제약으로 처리 불가

## 현재 한계

- 관리자 인증/권한 기능 없음
- 기존 버전 수정 UI 없음
- 가격 refresh job 상세 이력 UI 없음
- CSV import/export 없음
- role 템플릿 자체를 웹에서 생성하는 기능 없음
