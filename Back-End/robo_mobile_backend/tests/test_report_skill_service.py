from unittest.mock import patch

from mobile_backend.services import report_skill_service


def test_weekly_skill_prompt_combines_public_skills_then_alfin_rules():
    report_skill_service._SKILL_PROMPT_CACHE = None

    def fake_download(name: str, _url: str):
        return name, f"downloaded {name} instructions"

    with patch.object(report_skill_service, "_download_skill", side_effect=fake_download):
        prompt = report_skill_service.load_weekly_report_skill_prompt()

    assert "downloaded market-news-analyst instructions" in prompt
    assert "downloaded trade-sector instructions" in prompt
    assert "ALFIN report-style.SKILL.md" in prompt
    assert "ALFIN 프롬프트 ③" in prompt
    assert prompt.index("downloaded trade-sector") < prompt.index("ALFIN report-style")
