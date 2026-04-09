# WeRobo Mobile - Flutter Project Guidelines

## Project Overview
WeRobo is a robo-advisor mobile app built with Flutter. It helps users find optimal investment portfolios via an efficient frontier visualization and provides portfolio analysis, comparison, and rebalancing.

## Build & Run
- **Font**: Jalnan (custom, in `assets/fonts/`)
- **iCloud limitation**: iOS simulator builds fail from iCloud Drive paths. Always sync to `~/Developer/robo_mobile/` before running.
- **Run flow**: `rsync` project to local → `flutter pub get` → `flutter run -d <simulator_udid>`
- **Simulator**: iPhone 17 Pro (UDID: `6BFFDF4C-A1E8-4031-8883-6C660465972B`)

## Architecture
- **Pattern**: Feature-based organization with MVVM separation
- **Layers**:
  - `lib/app/` — Theme, colors, typography, app-wide config
  - `lib/screens/` — Screen widgets organized by feature (e.g., `onboarding/`)
  - `lib/screens/*/widgets/` — Reusable widgets scoped to a feature
- **State management**: Flutter built-in (`setState`, `ValueNotifier`, `ChangeNotifier`). No third-party state management unless explicitly requested.
- **Navigation**: `Navigator.push`/`pushReplacement` with `PageRouteBuilder` for custom transitions. Migrate to `go_router` when adding deep linking.

## Code Style

### Dart Conventions
- Follow Effective Dart guidelines
- `PascalCase` for classes, `camelCase` for members/variables/functions, `snake_case` for files
- Lines 80 characters or fewer
- Use `const` constructors wherever possible
- Prefer immutable widgets; use `StatelessWidget` when no state is needed
- Use arrow syntax for single-expression functions
- Null safety: avoid `!` unless value is guaranteed non-null
- Use exhaustive `switch` expressions
- `async`/`await` for all asynchronous operations

### Widget Patterns
- Composition over inheritance — compose small widgets, don't extend
- Private widget classes (`_MyWidget`) instead of helper methods returning widgets
- Break large `build()` methods into smaller private widget classes
- Use `ListView.builder` for long lists
- Separate UI logic from business logic

### Naming
- Meaningful, descriptive names — no abbreviations
- Screen files: `feature_screen.dart` (e.g., `splash_screen.dart`, `result_screen.dart`)
- Widget files: `descriptive_name.dart` (e.g., `donut_chart.dart`, `page_indicator.dart`)

## Design System

### Colors (from Figma, defined in `lib/app/theme.dart`)
**주 색상 (Primary sky blue palette):**
- 하늘색1: `#CFECF7`
- 하늘색2 / primaryLight: `#A0D9EF`
- 하늘색3: `#62C1E5`
- 하늘색4 / primary: `#20A7DB`
- 하늘색5 / primaryDark: `#1C96C5`

**부 색상 (Cool-tinted Neutrals):**
- 화이트: `#FFFFFF` (surface)
- 카드: `#EFF1F3` (cool-tinted)
- 보더: `#CDD1D6` (cool-tinted)
- 배경: `#F6F7F8`
- 텍스트 보조: `#6B6B6B`
- 텍스트 3차: `#8E8E8E` (WCAG AA 4.6:1)
- 블랙: `#000000`

### Fonts (from Figma)
| Usage | Font | Flutter family key |
|-------|------|--------------------|
| 디스플레이/로고 | 여기어때 잘난체 (Jalnan) | `Jalnan` |
| 본문 (Body) | Noto Sans Korean | `NotoSansKR` |
| 캡션 (Caption) | Gothic A1 | `GothicA1` |
| 숫자 (Numbers) | Google Sans Flex | `GoogleSansFlex` |
| 영어 (English) | IBM Plex Sans | `IBMPlexSans` |

### Typography Hierarchy (strictly follow this)
| Role | Style | Size | Weight | When to use |
|------|-------|------|--------|-------------|
| Logo | `logo` | 48px Jalnan | 700 | Splash + login logo ONLY |
| Hero text | `heading1` | 28px NotoSansKR | 700 | Reserved for rare hero moments |
| Page title | `heading2` | 22px NotoSansKR | 600 | Top of every screen |
| Section header | `heading3` | 18px NotoSansKR | 600 | Card titles, chart center labels |
| Body | `body` | 16px NotoSansKR | 400 | Descriptions, subtitles |
| Body small | `bodySmall` | 14px NotoSansKR | 400 | List items, badges, secondary text |
| Button | `button` | 16px NotoSansKR | 600 | Button labels |
| Caption | `caption` | 12px GothicA1 | 400 | Hints, legends, stat labels |
| Numbers | `number` | 28px GoogleSansFlex | 500 | Chart percentages, stats |

### Components
- Buttons: 52px height, 12px border radius, full-width
- Cards: 16px border radius, `#F0F0F0` background
- Page indicators: pill-style active dot (24px wide), 8px inactive dots

## Figma Reference
- Main design file: `PPusQaZqO8SE0KiCzDtUsf`
- Vestor UI Kit (copied): `9UxSEgw5zJWw0Qf9i3HLIN`

## Dependencies
- `cupertino_icons` — iOS-style icons
- `flutter_lints` — Lint rules
- Only add packages when explicitly needed. Prefer built-in Flutter solutions.

## Testing
- Widget tests in `test/`
- Follow Arrange-Act-Assert pattern
- Use `package:flutter_test` for widget tests
- Prefer fakes/stubs over mocks

## Accessibility
- Minimum 4.5:1 contrast ratio for text
- Touch targets minimum 44x44px
- Test with dynamic text scaling
- Use `Semantics` widget for screen reader labels

## gstack
- Use `/browse` skill from gstack for **all web browsing**. Never use `mcp__Claude_in_Chrome__*` tools.
- Available skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

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

## Quality Checklist
- [ ] No `print()` — use `dart:developer` log
- [ ] `const` constructors where possible
- [ ] No unnecessary rebuilds
- [ ] Error handling for async operations
- [ ] Responsive layout (test multiple screen sizes)
