# Public release polish plan — Real-Time Virtual Pet

| Field | Value |
|-------|--------|
| **Status** | Active plan (v0.2 public release track) |
| **Date** | 2026-07-04 |
| **Current version** | 0.1.0 playable MVP (public source) |
| **Target** | **v0.2.0 “Public playable”** — clone or download, play a real day, care/death/bury/re-adopt without agent hand-holding |
| **Repo** | https://github.com/i-apologise/real-time-virtual-pet |

Related docs: design (`design-real-time-virtual-pet.md`), presentation roadmap, playtest review, UX checklist, README.

---

## 1. What “public ready” means (exit criteria)

Ship **v0.2** only when **all** of these are true:

### Product
- [ ] First-time player can go **tutorial → adopt → care → leave & return → still correct state** without reading design docs.
- [ ] **Sleep, cooldowns, inventory, care points** survive restart (proven by automated tests + manual checklist).
- [ ] Death → backyard dig → grave visible → re-adopt is clear and non-soft-locking.
- [ ] CARE menu cooldowns, suggestions, and session check-in are understandable on first use.
- [ ] Town / park / store / home / backyard navigation never strands the player (door regression checklist green).

### Presentation
- [ ] Species (blob / pup / owl) are **visually distinct** at a glance while walking/idle.
- [ ] Home does not read as “empty prototype” (props + state reaction already started — finish the pass).
- [ ] Care success/fail always has **audio + visual feedback** (juice baseline exists — tune volumes/spam).
- [ ] README screenshots match **current** main (refresh if UI drifts).

### Packaging
- [ ] **Desktop exports** for at least **macOS** and **Windows** (Linux nice-to-have).
- [ ] Release page or README section: download link, Godot version if editor-only fallback, known issues.
- [ ] App name, icon, window title consistent; no debug-looking default only.

### Quality / trust
- [ ] Headless suite **green on CI** for every release PR.
- [ ] Manual **release smoke** run (below) signed off once per release candidate.
- [ ] LICENSE chosen (even “all rights reserved” or MIT — explicit).
- [ ] No secrets / personal save paths / tokens in repo.

### Explicitly **not** required for v0.2
- Multiplayer, more species, mobile, Steam achievements, soft-floor “can’t die” mode as default.
- Perfect pixel art parity with commercial titles.
- Full controller support (stretch).

---

## 2. Current baseline (honest)

| Area | State | Public risk |
|------|--------|-------------|
| Core sim (needs, death, catch-up) | Strong | Low if tests stay green |
| Save / resume | Good after sleep fix | Medium — more fields need restart tests |
| Care UX | Good (menu, cooldowns, suggest) | Low |
| Town / park / store / yard | Playable | Medium — still blocky / thin content |
| Graphics | Acceptable MVP | **High** for “first impression” |
| Audio | Basic SFX + ambient | Medium — volumes/spam |
| Economy (care points) | Thin loop | Low for v0.2 if labeled experimental |
| Export / install | **Missing** | **Blocker for non-dev players** |
| License | TBD | Blocker for clear public use |

---

## 3. Workstreams (PR-sized)

Do in order unless noted. Prefer **fewer, larger PRs** that still ship in ≤ few days each.

### Track R0 — Release packaging (**blocker**)

| PR | Scope | Done when |
|----|--------|-----------|
| **R0.1 Export presets** | Godot export presets for macOS/Windows; app icon; product name | Builds run on a clean machine |
| **R0.2 Release artifacts** | GitHub Release v0.2.0-rc1 with zips; README “Download” section | Non-dev can play without cloning |
| **R0.3 License + legal basics** | LICENSE file; update README license; short “what this is / not” | Repo legally legible |

### Track R1 — First-hour experience

| PR | Scope | Done when |
|----|--------|-----------|
| **R1.1 Onboarding pass** | Tutorial text accuracy; first-adopt store flow; one “what happens when you close the game” line | New player understands real-time stakes |
| **R1.2 Session & toasts** | Session banner not spammy; toasts auto-dismiss ~3s; optional last-5 event log | HUD feels calm |
| **R1.3 Settings stub** | Mute SFX/ambient; optional hide ETAs | Basic accessibility / preference |

### Track R2 — Presentation (first impression)

| PR | Scope | Done when |
|----|--------|-----------|
| **R2.1 Home art finish** | Complete furniture set; less empty floor; consistent palette | Screenshot looks intentional |
| **R2.2 Species motion pass** | Distinct idle/walk/react frames for blob/pup/owl | Species readable in motion |
| **R2.3 Care juice tune** | Particle rate/color; SFX volume table; no spam | Care feels rewarding not noisy |
| **R2.4 UI chrome** | CARE panel, stats, banners share one style system | Cohesive “product UI” |

### Track R3 — Core fantasy payoff

| PR | Scope | Done when |
|----|--------|-----------|
| **R3.1 Death & burial ceremony** | Short dig ritual; epitaph input that sticks; grave shows name/species/days | Death hurts in a good way |
| **R3.2 Graveyard browsing** | Select headstone → details panel | History feels permanent |
| **R3.3 Status copy pass** | All fail/success strings player-facing; no raw enums in any path | Zero `PET_SLEEPING`-style leaks |

### Track R4 — World reasons to leave home (light)

| PR | Scope | Done when |
|----|--------|-----------|
| **R4.1 Park loop** | Fetch + one more interaction (bench rest / short play); clear bonus copy | Park is purposeful |
| **R4.2 Store loop** | Balance care-point earn/spend; 1–2 more items max; inventory visible at home | Economy not confusing |
| **R4.3 Town readability** | Building silhouettes/labels; no soft-lock doors | Map scannable in 5s |

### Track R5 — Real-time robustness (parallel with R0–R2)

| PR | Scope | Done when |
|----|--------|-----------|
| **R5.1 Persist matrix tests** | Sleep, cooldowns, inventory, care points, escort flag across simulated restart | CI catches regressions |
| **R5.2 Long-AFK scenarios** | Catch-up matrix expansions (sleep mid-away, death while closed) | Design promises hold |
| **R5.3 Manual smoke script** | Checked list in `docs/RELEASE-SMOKE.md` | Human sign-off path |

### Track R6 — Stretch (after v0.2 tag)

- Difficulty presets (cozy / classic).
- Life stages.
- Photo/scrapbook.
- Linux export.
- Optional opt-in desktop notifications for critical needs.
- Controller support.

---

## 4. Recommended sequence (critical path)

```text
R0.1 Export ─┬─► R0.2 Release zips ─► R0.3 License
             │
R5.1 Persist tests (start early, merge anytime)
             │
R1.1 Onboarding ─► R1.2 Toasts ─► R1.3 Settings
             │
R2.1 Home art ─► R2.2 Species motion ─► R2.3/R2.4 juice+UI
             │
R3.1–R3.3 Death ceremony + copy
             │
R4.1–R4.3 Park/store/town tune
             │
Manual smoke (R5.3) ─► tag v0.2.0
```

**Minimum path to “public playable” if time is tight:**

1. R0.1 + R0.2 (people can run it)  
2. R5.1 (don’t ship broken real-time)  
3. R1.1 + R2.1 (first hour + first screenshot)  
4. R3.1 (death fantasy)  
5. Smoke + tag  

Everything else improves quality but is secondary to **install + trust + first impression + death loop**.

---

## 5. Manual release smoke (every RC)

Record pass/fail in `docs/RELEASE-SMOKE.md` (create when first RC builds).

1. Fresh save (or delete `user://saves`).
2. Tutorial → adopt blob → home.
3. FEED / CLEAN / SLEEP → quit fully → reopen within 5 min → still sleeping or correct awake state.
4. WAKE → WALK → town → park → fetch or end walk → home.
5. Buy one store item → use effect once.
6. F8 or long away → death → backyard dig → grave → store re-adopt.
7. Mute settings if present.
8. Export build: same flow without editor.

---

## 6. Quality bar per PR (release track)

- CI green (Godot tests + PR body standards).
- ≥1 screenshot under `docs/pr-screenshots/` for UI/export PRs.
- No raw sim reason codes in player toasts.
- No new public CDN for assets (in-repo only).
- Prefer not to expand scope mid-PR; cut stretch to R6.

---

## 7. Roles / cadence (suggestion)

| Cadence | Action |
|---------|--------|
| Per PR | Implement → test → screenshot → open PR → user merges |
| Weekly | Play 20–30 min real-time (not only F7); note friction |
| RC | Full smoke + export on clean machine |
| Post v0.2 | Collect issues from public repo; prioritize by first-hour pain |

User merges; agent does not merge unless explicitly asked.

---

## 8. Success metrics (lightweight)

Not analytics — judgment calls:

- Can a friend play 15 minutes with only the README?
- Does restart feel “fair” after sleep/care?
- Is the first GitHub screenshot something you’re willing to show strangers?
- Does losing a pet feel sad, not confusing?

---

## 9. Open decisions (resolve before or during R0)

1. **License:** MIT vs ARR vs CC for assets separately?  
2. **Platform priority:** macOS-first export OK for RC1?  
3. **Death default:** keep classic permanent death (recommended) vs optional cozy mode in v0.2?  
4. **Branding:** final game title string for window/export (still “Real-Time Virtual Pet”?).

---

## 10. Immediate next PR (proposal)

**Start with R0.1 + R5.1 in parallel if possible:**

- **PR-A:** Export presets + icon + README download placeholder.  
- **PR-B:** Automated restart/persist tests (sleep already partly covered; cooldowns + inventory + care points).

Then **R1.1 onboarding** and **R2.1 home art finish** for first-impression.

---

*This plan is the release track source of truth until v0.2.0 is tagged. Update checkboxes as PRs merge.*
