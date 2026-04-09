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
- `equal_weight_basket`
  - 후보 종목 전체를 동일비중 바스켓으로 사용
- `equal_weight_dividend_basket`
  - 후보 종목 전체를 동일비중 바스켓으로 사용
  - 배당 지급 이력이 있는 종목은 최근 지급 주기를 추정해 연환산 배당수익률을 계산
  - 계산된 배당수익률을 바스켓 기대수익률에 동일비중으로 가산

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
    "role_key": "equal_weight_basket"
  },
  {
    "asset_code": "infra_bond",
    "role_key": "equal_weight_dividend_basket"
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
- `equal_weight_dividend_basket`은 배당 지급 이력과 최근 지급 주기를 추정할 수 있는 종목에서 가장 잘 동작합니다.

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
