"""Load the report skills named by the user-supplied ALFIN report package.

The package defines skills as prompt documents, not executable libraries. The
public documents are pinned to reviewed GitHub commits and combined with the
package's Korean style and weekly-output rules. The Korean rules are appended
last so they override recommendation language in upstream trading skills.
"""

from __future__ import annotations

import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

import httpx

logger = logging.getLogger(__name__)

_SKILL_TIMEOUT_SECONDS = 8.0
_SKILL_PROMPT_CACHE: str | None = None

_SKILL_URLS = {
    "market-news-analyst": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/market-news-analyst/SKILL.md"
    ),
    "market-news corporate impact reference": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/market-news-analyst/"
        "references/corporate_news_impact.md"
    ),
    "market-news geopolitical reference": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/market-news-analyst/"
        "references/geopolitical_commodity_correlations.md"
    ),
    "market-news event-pattern reference": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/market-news-analyst/"
        "references/market_event_patterns.md"
    ),
    "market-news source reference": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/market-news-analyst/"
        "references/trusted_news_sources.md"
    ),
    "trade-sector": (
        "https://raw.githubusercontent.com/zubair-trabzada/ai-trading-claude/"
        "c6d7252211a72405cefaff3e62d27a032c58348c/skills/trade-sector/SKILL.md"
    ),
    "market-environment-analysis": (
        "https://raw.githubusercontent.com/tradermonty/claude-trading-skills/"
        "9ef78d691bfc188171a42b51d17053833955a36e/skills/"
        "market-environment-analysis/SKILL.md"
    ),
    "client-report": (
        "https://raw.githubusercontent.com/anthropics/financial-services/"
        "69cbc81467a5dced793eee03dec4658aa24ef856/plugins/vertical-plugins/"
        "wealth-management/skills/client-report/SKILL.md"
    ),
    "plain-language-iso-24495": (
        "https://raw.githubusercontent.com/nikdumroese/plain-language-skill/"
        "6d6a69d91ff95b07073f65393e56e2a734b670b7/skills/"
        "plain-language-iso-24495/SKILL.md"
    ),
    "plain-english": (
        "https://raw.githubusercontent.com/b1rdmania/claude-plain-english-skill/"
        "567dac51a047c81e9314542023baaa2d5ff650f0/skills/plain-english/SKILL.md"
    ),
}

_WEEKLY_SKILL_NAMES = {
    "market-news-analyst",
    "market-news corporate impact reference",
    "market-news geopolitical reference",
    "market-news event-pattern reference",
    "market-news source reference",
    "trade-sector",
}

SKILL_SOURCE_URLS = [
    "https://github.com/tradermonty/claude-trading-skills",
    "https://github.com/zubair-trabzada/ai-trading-claude",
    "https://github.com/anthropics/financial-services",
    "https://github.com/nikdumroese/plain-language-skill",
    "https://github.com/b1rdmania/claude-plain-english-skill",
]

_REPORT_STYLE_RULES = r"""
[ALFIN report-style.SKILL.md - ZIP 원문, 공개 스킬보다 우선]

A. 사실성 (최우선)
1. 모든 문장은 숫자 또는 출처가 있다. 없으면 지운다.
2. 예측·권고·평가어("사라", "좋아 보인다", "유망") 금지.
   시스템 동작은 "시스템이 ~한다"로 사실 서술한다.
3. 확인 안 된 것은 "이유 모름" 또는 "미확인"으로 적는다. 추정으로 채우지 않는다.
4. 상대 날짜("최근", "곧") 대신 날짜를 쓴다.
5. 등락률·지수 수치는 웹 기사에서 인용하지 않는다. 우리 종가 테이블에서 계산한다.
   웹은 "왜"(사건·공시·보도)만 담당한다.
6. 가격 캐시를 장중에 받지 않는다. 미국 마감 이후에만 갱신한다.
7. 배포 전 숫자 대사를 실행한다. 어긋난 숫자는 우리 종가로 고친다.

B. 구조 (ISO 24495-1 번안)
1. 첫 화면에 결론: 한 줄 요약 + 핵심 숫자 3개가 제일 위에 온다.
2. 제목만 읽어도 흐름이 잡히게 쓴다.
3. 항목마다 "무슨 일 / 왜 / 나한테" 3줄 구조를 쓴다.
4. 독자 다수가 필요한 정보 먼저, 일부만 필요한 상세는 뒤에 둔다.
5. 경고·주의는 해당 내용보다 앞에 둔다. 일정은 시간 순서대로 쓴다.
6. 문단은 3~5문장, 한 문단에는 한 생각만 담는다.
7. 마지막에 다음 확인일과 챙길 일정이 있다.

C. 문장 (ISO + Orwell/Gowers 번안)
1. 한 문장 한 생각. 40자를 넘으면 쪼갠다.
2. 능동태를 쓴다. "비중이 조정되었다" 대신 "시스템이 비중을 조정했다"라고 쓴다.
3. 빼도 뜻이 같은 단어는 뺀다.
4. 부정형보다 긍정형을 쓴다.
5. 조건이 먼저 온다. "금리가 오르면 → 리츠에 불리" 순서다.
6. 문장 길이를 섞는다.

D. 용어 (한국어 금융 리포트 전용)
1. 전문용어·영어 약어는 첫 등장에 괄호로 풀이한다.
2. 한 개념에는 한 단어만 쓴다. 같은 뜻의 단어를 돌려 쓰지 않는다.
3. 랠리는 상승세, 모멘텀은 오름세, 헤지는 위험 분산,
   가이던스는 회사 전망으로 쓴다.
4. 금지어: "~의 관점에서", "종합적으로 볼 때", "주목할 만한", "견조한",
   "우호적인", "다각적인", "귀추가 주목된다".
5. 서론과 마무리 요약을 쓰지 않는다. 답부터 시작하고 다음 일정으로 끝낸다.
6. 줄표는 200자당 1개까지만 쓴다.
7. 근거 없는 권위를 쓰지 않는다. "전문가들은", "시장에서는" 대신 기관명을 쓴다.

E. 예외
- 인용문, 기사 제목, 회사·상품 공식 명칭, 법적 고지는 바꾸지 않는다.
- 전략 이름은 유지하되 첫 등장에 뜻을 푼다.

검수 순서
0) 숫자 대사 → 1) 사실성 → 2) 첫 화면 결론 → 3) 문장·용어 →
4) 용어 통일 → 5) 줄표·문장 길이 확인.
""".strip()

_WEEKLY_OUTPUT_RULES = r"""
[ALFIN 프롬프트 ③ - 주간 요약]
- 최근 10거래일 market_close 데이터와 확인된 뉴스 제목을 사용한다.
- 시장 뉴스 절차서의 기준으로 사건을 정렬한다.
  정렬 기준값 = 가격충격(10/7/4/2/1) × 파급(3/2/1.5/1) × 전망수정(0.75~1.5)
- 이 계산값은 화면에 점수로 표시하지 않는다.
- 출력 순서는 고정한다.
  1) 이번 주, 한 줄로
  2) 핵심 숫자 3개
  3) 이번 주 큰 사건 다섯 가지
  4) 돈이 어느 업종으로 가고 있나
  5) 경기 신호등
  6) 다음 주 일정
  7) 고객님 업종 한 줄
- 큰 사건마다 무슨 일, 왜, 고객님께 어떤 의미인지 쓴다.
- 경기 신호등은 제조업 지수, 실업률, 물가, 기준금리, 30년 국채 금리 순서로 쓴다.
- 신호등과 숫자는 백엔드가 주입한 값을 그대로 사용하고 모델이 다시 계산하지 않는다.
- 전망과 매수·매도 권유를 쓰지 않는다.

사건 순서표 앞에는 다음 뜻을 그대로 유지해 안내한다.
'순서를 정하는 기준은 가격이 얼마나 움직였는지, 몇 개 시장에 퍼졌는지,
앞으로의 전망을 바꿨는지입니다. 이 순서는 예측이 아니라 매주 같은 방식으로
정리하기 위한 편집 기준입니다. 위쪽에 있다고 앞으로 더 움직인다는 뜻은 아닙니다.'
""".strip()


def _download_skill(name: str, url: str) -> tuple[str, str]:
    response = httpx.get(url, timeout=_SKILL_TIMEOUT_SECONDS, follow_redirects=True)
    response.raise_for_status()
    text = response.text.strip()
    if len(text) < 200:
        raise ValueError(f"skill document is unexpectedly short: {name}")
    return name, text


def load_weekly_report_skill_prompt() -> str:
    """Return the exact pinned public skills plus ZIP-owned override rules."""

    global _SKILL_PROMPT_CACHE
    if _SKILL_PROMPT_CACHE is not None:
        return _SKILL_PROMPT_CACHE

    downloaded: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=len(_SKILL_URLS)) as executor:
        futures = {
            executor.submit(_download_skill, name, url): name
            for name, url in _SKILL_URLS.items()
        }
        for future in as_completed(futures):
            name = futures[future]
            try:
                key, text = future.result()
                downloaded[key] = text
            except Exception:
                logger.warning("report skill download failed: %s", name, exc_info=True)

    ordered = [
        f"[{name}]\n{downloaded[name]}"
        for name in _SKILL_URLS
        if name in downloaded and name in _WEEKLY_SKILL_NAMES
    ]
    if "market-news-analyst" not in downloaded or "trade-sector" not in downloaded:
        logger.warning("weekly report is running with partial public skill context")

    ordered.extend([_REPORT_STYLE_RULES, _WEEKLY_OUTPUT_RULES])
    _SKILL_PROMPT_CACHE = "\n\n".join(ordered)
    return _SKILL_PROMPT_CACHE
