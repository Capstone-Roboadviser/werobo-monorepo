# Capstone Meeting Todos

Split into four todo files, one per worktree. Each file lists only the files it modifies. No two files overlap, so all four worktrees can run in parallel.

## Worktrees

| File | Scope | Files modified |
|---|---|---|
| `home.md` | Home screen overhaul | `home_tab.dart` |
| `frontier.md` | Efficient Frontier polish | `onboarding_screen.dart`, `efficient_frontier_chart.dart` |
| `gradient.md` | Gradient bar and asset colors | `asset_weight.dart`, `theme.dart` |
| `digest.md` | Digest screen redesign | `digest_screen.dart` (and digest widgets) |

## How to run in parallel

For each todo file:

```bash
# from the repo root
git worktree add ../werobo-home honge6090/home-screen-work
cd ../werobo-home
# open Claude Code here and feed it todos/home.md
```

Repeat for frontier, gradient, digest. Each worktree gets its own branch and Claude Code session.

Merge order suggestion (lowest conflict risk first):
1. `gradient` (theme tokens, isolated widget)
2. `frontier` (onboarding only)
3. `digest` (digest screen only)
4. `home` (largest scope, merge last to absorb any token renames from `gradient`)

## Not included (handled out of band)

- 소르티노 비율 추가: needs 교수님 discussion on Monday before implementing.
- 희재님 작업 정리 업로드: organizational task, not code.
- 알림 아이콘 디자인 리서치: design task, not code. Once icons are picked, add them to the digest and home worktrees.

## Style rules (apply to all worktrees)

- Do NOT add Claude as a co-author on commits.
- No em dashes or en dashes.
- Plain prose, simple vocabulary, short sentences.
- Do not use "quiet" or "quietly" figuratively.
- Follow the project's CLAUDE.md.
