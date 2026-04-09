# WeRobo — Monorepo

Robo-advisor mobile app for Korean retail investors. Interactive efficient frontier visualization, portfolio analysis, comparison, and rebalancing.

## Structure

- `Front-End/robo_mobile/` — Flutter mobile app (iOS primary, Android secondary)
- `Back-End/robo_mobile_backend/` — FastAPI backend deployed on Railway

Each subdirectory has its own CLAUDE.md with detailed conventions. Refer to those for stack-specific guidance.

## Subtree Workflow

This is a git subtree monorepo. Both subdirectories track their original GitHub repos:

```bash
# Pull latest from upstream repos
git subtree pull --prefix=Back-End/robo_mobile_backend backend main
git subtree pull --prefix=Front-End/robo_mobile frontend main

# Push monorepo changes back to upstream repos
git subtree push --prefix=Back-End/robo_mobile_backend backend main
git subtree push --prefix=Front-End/robo_mobile frontend main
```

## Cross-Repo Context

- Backend API base: Railway deployment (see `Back-End/robo_mobile_backend/railway.json`)
- Frontend consumes backend via `lib/services/` API clients
- Ship target: 2026-05-28 (MVP)
- KIS brokerage integration is OUT OF SCOPE for MVP

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
