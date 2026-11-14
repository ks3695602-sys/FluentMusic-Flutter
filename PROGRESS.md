# PROGRESS — FluentMusic v1.4.0
**Live ledger. Update every 5 minutes. Append-only session log at bottom.**

---

## 🚨 RESUME CARD (read this first if anything crashed)

```
LAST UPDATED : 2026-11-14 20:05 IST
LAST COMMIT  : P4 71bf16f pushed · analyze 43601145551 green ✅ · P5 in working tree
BRANCH       : feat/v1.4.0-ios27-remake
CURRENT PHASE: P5 — Account + sync
CURRENT STEP : account/sync services + glass account page wired, docs/SYNC.md written
NEXT ACTION  : commit/push P5, confirm analyze green, then P6 library features
BLOCKED BY   : none
```

**How to resume**
1. `cd C:\Rough\Antigravity\FluentMusic-Flutter`
2. `git log --oneline -5` → find last checkpoint
3. Open phase checklist below → first unchecked box
4. Read `MASTERPLAN.md` + `GEMINI.md`
5. Continue **NEXT ACTION** only. Don't redo checked items.
6. Commit + push before starting anything risky.

---

## Status board

| Phase | Name | Status | % |
|---|---|---|---|
| P0 | Ground truth | ✅ done | 100 |
| P1 | Glass engine + Lab | ✅ done | 100 |
| P2 | Bottom bar + accessory | ✅ done | 100 |
| P3 | Home redesign | ✅ done | 100 |
| P4 | Settings remake | ✅ done | 100 |
| P5 | Account + sync | 🟡 in progress | 85 |
| P6 | Library features | ⬜ | 0 |
| P7 | Lyrics polish | ⬜ | 0 |
| P8 | Favourite popup | ⬜ | 0 |
| P9 | QA + single APK | ⬜ | 0 |

Legend: ⬜ todo · 🟡 in progress · ✅ done · 🔴 blocked

---

## Checklists

### P0 — Ground truth
- [x] `docs/GLASS_API.md` created with real signatures
- [x] `GlassSearchableBottomBar` checked (removed; use `GlassTabBar.searchable`)
- [x] `GEMINI.md` created
- [x] `.github/workflows/analyze-only.yml` created
- [x] analyze-only CI green — run [43598444551](https://github.com/ks3695602-sys/FluentMusic-Flutter/actions/runs/43598444551) ✅

### P1 — Glass engine + Lab
- [x] `lib/theme/glass_config.dart`
- [x] `lib/theme/glass_config_controller.dart` (+ Hive + scope)
- [x] `lib/widgets/glass/glass_lab_page.dart`
- [x] `lib/widgets/glass/glass_backdrop.dart`
- [x] old sliders removed from `settings_subpages.dart`
- [x] premium tier locked
- [x] light mode contrast check (solid sections + dark/light text tokens)

### P2 — Bottom bar
- [x] old Column removed
- [x] `GlassTabBar.searchable` + accessory
- [x] 4 tabs (Home/Search/Library/Settings) — Search auto-hides offline
- [x] inline search expand (bar → `InlineSearchBridge` → `SearchPage`)
- [x] mini player collapse (accessory = null while search open)
- [ ] bottom inset for content (done in P3 slivers)
- [x] bouncy spring tap (`pressScale: 0.96`)

### P3 — Home
- [x] CustomScrollView + slivers
- [x] large title collapse (`SliverPersistentHeader` + blur)
- [x] long sections list (Recents → Quick Picks → Playlists → Recommended → Artists → Recap → Genres)
- [x] spring physics (`BouncingScrollPhysics` + `AlwaysScrollable`)
- [x] content under bar (`SliverMiniPlayerBottomSpace`)
- [x] Songs before Artists

### P4 — Settings
- [x] 9 section cards (one coloured glass tile each)
- [x] colored icon badges
- [x] glass subpages (GlassScaffold + mesh background)
- [x] account page black-box fixed (new glass `account_page.dart`)
- [x] bottom fade pattern (shell extends body)

### P5 — Account + sync
- [x] `account_service.dart` (optional Supabase REST, local profile, token refresh)
- [x] `account_page.dart` (skip works, export/import, backup/restore)
- [x] `sync_service.dart` (JSON snapshot, union merge, export/import, auto-sync)
- [x] Supabase keys wired via `--dart-define` (optional at build time)
- [x] startup restore + post-frame auto-sync in `main.dart`
- [x] old account stub removed; `docs/SYNC.md` has SQL/RLS + 2-device script
- [ ] 2-device sync test (manual, needs real Supabase keys)

### P6 — Library
- [ ] add songs
- [ ] search in add-song
- [ ] delete song
- [ ] playlist create
- [ ] artist section improved

### P7 — Lyrics
- [ ] long-token wrap
- [ ] active word scale
- [ ] multi-line/RTL safe
- [ ] tests green

### P8 — Popup
- [ ] `glass_toast.dart`
- [ ] favourite call sites
- [ ] queue + dismiss

### P9 — Ship
- [ ] analyze green
- [ ] tests green
- [ ] ONE release APK built
- [ ] device checklist
- [ ] version 1.4.0+13
- [ ] tag v1.4.0 + release

---

## 5-minute update format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️ T+00:35 | PHASE P1 | 62% | vibe: 🧊
✅ Done: glass_config + controller
🔨 Now: glass_lab_page sliders bind
⏭️ Next: delete old sliders
🐛 Blocked: none
💾 Commit: 3f2a1c9 (pushed)
📄 Files touched: 2
😹 Joke: glass itna clear ki ex ka message bhi dikh jaye (unfortunately)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Checkpoints (commit + push points)

| # | After | Commit | Pushed |
|---|---|---|---|
| 0 | P0 + P1.1 | `d0a6346` | ✅ |
| 1 | P1 (Lab + theme) | `ce12313` + `6d3a023` | ✅ |
| 2 | P3 | `7f1fd07` | ✅ |
| 3 | P4 | `71bf16f` | ✅ |
| 4 | P5 | — | ⬜ |
| 5 | P7 | — | ⬜ |
| 6 | P9 | — | ⬜ |

---

## Session log (append only)

```
[2026-11-14 18:05] Plan created. MASTERPLAN.md + PROGRESS.md written.
[2026-11-14 18:05] Branch feat/v1.4.0-ios27-remake created. No code changes yet.
[2026-11-14 18:07] Docs commit 94e52ea pushed (MASTERPLAN, PROGRESS, GEMINI).
[2026-11-14 18:22] liquid_glass_widgets 1.17.3 source extracted; signatures verified.
[2026-11-14 18:30] docs/GLASS_API.md written (real API, 8-slider mapping, traps).
[2026-11-14 18:35] glass_config.dart + glass_config_controller.dart written.
[2026-11-14 18:38] analyze-only.yml added (push feat/**, paths-filtered, no APK).
[2026-11-14 18:40] Commit d0a6346 pushed (P0 + P1 turn 1).
[2026-11-14 18:44] Analyze run 43598444551 = success ✅ (P0 gate green).
[2026-11-14 18:52] glass_backdrop.dart (mesh gradient, cheap, no shaders).
[2026-11-14 18:58] glass_lab_page.dart (8 sliders + live preview + reset/copy/paste).
[2026-11-14 19:02] Config hooked into global GlassThemeData (tint/aberration/refraction) + GlassConfigScope in main.
[2026-11-14 19:04] Old blur/thickness/quality/tint sliders deleted from Appearance subpage.
[2026-11-14 19:08] P1.2 committed ce12313 + 6d3a023; analyze run 43599325109 green ✅.
[2026-11-14 19:12] P2: search_bridge.dart + GlassTabBar.searchable + accessory MiniPlayer + 4 tabs.
[2026-11-14 19:20] P2: SearchPage consumes bridge query; PopScope/offline reset search state; Search tab hidden offline.
[2026-11-14 19:24] P2 commit 5db482e pushed; analyze run 43600458379 green ✅.
[2026-11-14 19:32] P3: home rewritten to slivers, collapsing Listen Now header, spring scroll, 150px dock inset.
[2026-11-14 19:36] P3: Quick Picks rail, circular Artists rail (songs first), genre chips → inline search bridge.
[2026-11-14 19:40] P3 commit 7f1fd07 pushed; analyze run 43600876797 green ✅.
[2026-11-14 19:46] P4: settings rebuilt as 9 separate tinted glass tiles (image 10 pattern), 1.4.0 header, dock spacer.
[2026-11-14 19:52] P4 commit 71bf16f pushed; analyze run 43601145551 green ✅.
[2026-11-14 19:58] P5: account_service (Supabase REST + local profile), sync_service (union merge, JSON export/import).
[2026-11-14 20:02] P5: glass account page, old stub removed, startup restore + auto-sync wired in main.dart.
[2026-11-14 20:04] P5: docs/SYNC.md with SQL/RLS, build keys, honest limits, 2-device script.
```
