# GEMINI.md — FluentMusic AI Rules

Read this before touching code. Then read `MASTERPLAN.md` and `PROGRESS.md`.

## Read order
1. `PROGRESS.md` → RESUME CARD → current phase
2. `MASTERPLAN.md` → phase details
3. `docs/GLASS_API.md` → real package signatures (never guess)

## Commands
```powershell
cd C:\Rough\Antigravity\FluentMusic-Flutter
git rev-parse --show-toplevel        # must be ...\FluentMusic-Flutter
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```
No local Flutter SDK? Use CI (`Analyze` job) as the gate. Never claim "works" without a green run.

## Hard rules
- **3–4 files per turn.** No big-bang refactors.
- Code must compile after every turn.
- Commit + push every 20–30 min. Update `PROGRESS.md` every 5 min.
- **Do not build APK** until P9. Analyze-only is enough mid-way.
- Never use a `Glass*` symbol you have not verified in `docs/GLASS_API.md`.
- Never nest glass inside glass. One `GlassBackdropGroup` per region.
- Local-first: account/sync must never block the app.
- Do not remove existing working features (lyrics sync, playback) while refactoring.

## Known traps (already burned us)
| Trap | Correct |
|---|---|
| `GlassAdaptiveScope.maybeOf` | `GlassAdaptiveScopeData.maybeOf(context)` |
| `hide ColorScheme` on liquid_glass_widgets import | remove `hide ColorScheme` (package doesn't export it) |
| `ThemeMode` from `flutter/material` + `app_themes.dart` | `app_themes` uses `material_ui` ThemeMode → import both consistently |
| `GlassIconButton` undefined | import `package:liquid_glass_widgets/liquid_glass_widgets.dart` |
| Removing `colorScheme` variable as "unused" | it is used later in the same build method |
| Android lint crash in release (`lintVitalAnalyzeRelease`) | disable `checkReleaseBuilds` for throwaway/demo builds only |

## Style
- Match existing naming/structure (`lib/screens`, `lib/widgets`, `lib/services`).
- Prefer small widgets over giant build methods.
- No new dependency without a one-line reason in the commit message.

## Definition of done (per phase)
- Analyze green
- Phase checklist in `PROGRESS.md` fully checked
- Commit pushed
- Progress block posted

## If stuck
Write in `PROGRESS.md`:
```
🔴 BLOCKED: <exact error>
FILE:LINE: <path:line>
LAST GOOD COMMIT: <sha>
TRIED: <what you tried>
```
Then stop. Do not thrash.
