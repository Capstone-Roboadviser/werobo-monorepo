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
