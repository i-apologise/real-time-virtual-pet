# UX/UI polish plan — public-facing surfaces

| Field | Value |
|-------|--------|
| **Status** | Draft for review → implement next |
| **Date** | 2026-07-04 |
| **Focus** | Player-facing **UX/UI only** (not export, not new sim systems) |
| **Goal** | Cohesive, readable, calm UI that matches a “real game” first hour — not scattered labels and prototype panels |

**In scope:** layout, hierarchy, feedback, input affordances, visual consistency, copy on screen.  
**Out of scope for this plan:** Godot export packages, new species, multiplayer, major economy redesign (only *how* shop is shown).

Related: `PUBLIC-RELEASE-POLISH-PLAN.md` (R1–R2 tracks), `UX-POLISH-CHECKLIST.md`, playtest screenshots under `docs/readme-screenshots/`.

---

## 1. What’s already decent

| Surface | Strength |
|---------|----------|
| CARE menu | High-contrast panel, selected row, cooldowns / greyed rows (post #18/#22) |
| Need meters | Numbers + ETAs + suggested line + flash on change |
| Session banner | Check-in after AFK (exists; needs spam/placement tune) |
| Care feedback | Juice sparks, emotes, SFX (exist; need volume/spam tune) |
| Sleep visibility | Zzz + gate messages |
| Store pens | Walkable store concept is better than pure cards |

**Do not rebuild these from scratch** — unify and refine.

---

## 2. Lacking areas (prioritized)

### P0 — First impression & hierarchy (**biggest lack**)

| Gap | Why it hurts |
|-----|----------------|
| **No shared UI kit** | Habitat uses light panels; town/park/yard use raw white labels + bare buttons; store mixes both. Reads as different games. |
| **HUD clutter (home)** | Top-left stacks deaths/❤, long hint string, toast, nav buttons; top-right stats are dense; center timer + session banner compete. |
| **World labels as UI** | Floor text (“HOUSE DOOR”, “Bowl looks empty”) fights pixel fantasy and readability at camera zoom. |
| **Fixed pixel positions** | Many `Vector2(8, 26)` HUDs ignore safe margins / scale; breaks on different window sizes. |

### P1 — Feedback & calmness

| Gap | Why it hurts |
|-----|----------------|
| **Toasts never expire** | Stale “Fed!” or errors stick until overwritten — looks broken. |
| **Hint text too long** | Permanent control essay at top; veterans don’t need it. |
| **Session banner placement/duration** | Can feel random or cover action; needs consistent “product” treatment. |
| **Progress bars unstyled** | Default Godot bars clash with custom panels. |
| **Emote/juice spam risk** | Passive bubbles can stack with Zzz and room notes. |

### P2 — Input & discoverability

| Gap | Why it hurts |
|-----|----------------|
| **Keyboard-only CARE / most UI** | No click-to-select on menu rows or shop (mouse users struggle). |
| **Inconsistent E semantics** | Door / CARE / dig-hold / end-walk / pen / reception — same key, weak on-screen verb. |
| **No pause / settings screen** | Can’t mute or re-read controls without README. |
| **Tutorial vs live HUD mismatch** | Tutorial may not match current CARE/cooldowns/❤ currency. |

### P3 — Per-scene thinness (UI/UX, not full art)

| Scene | Lack |
|-------|------|
| **Town** | Doorsteps unclear; labels float; no “you are here” / destination preview. |
| **Park** | “Play fetch” is a floating Button, not world-integrated; bonus not explained in HUD. |
| **Store** | Shop panel + world + adopt modal fight for attention; no single “mode” (browse vs checkout). |
| **Backyard** | Functional after door fix; dig progress and house door still feel like debug UI. |
| **Death panel** | Modal-ish panel OK but style inconsistent with CARE. |

### P4 — Accessibility / polish details

| Gap |
|-----|
| No focus ring / scalable font option |
| Color-only need urgency (no icon or pattern) |
| Day/night has no small phase chip in HUD |
| Care points (❤) not explained on first earn |

---

## 3. Design principles (for all polish PRs)

1. **One chrome system** — cream/light panel + dark text + 2–3px border + soft (home CARE style is the reference).
2. **One accent** — red/crimson for selection & urgent suggest only.
3. **Three HUD zones max on home:** (A) identity/status, (B) needs, (C) transient feedback.
4. **Transient ≠ permanent** — toasts and emotes die; meters and doors stay.
5. **Verb on the verb key** — when E does something, on-screen string starts with that verb (“Open CARE”, “Enter town”, “Hold to dig”).
6. **Mouse parity for menus** — if it’s a list, it should be clickable.
7. **Don’t invent systems** — polish presentation of existing cooldowns, suggest, ❤, park bonus.

---

## 4. Target information architecture (home)

```text
┌─────────────────────────────────────────────────────────────┐
│ [Pet name · state]  Deaths·Graves·❤     [day phase chip]   │  ← slim top bar
│ Suggested: FEED · ready in —                                │  ← one line, optional
├─────────────────────────────────────────────────────────────┤
│                                              ┌────────────┐ │
│                                              │ Needs card │ │  ← existing meters
│              game world                      │ + ETAs     │ │
│                                              └────────────┘ │
│  [CARE panel when open — bottom-left, product style]        │
│                                                             │
│  bottom: context verb only (“Near Mochi — E Open CARE”)     │  ← replaces essay
└─────────────────────────────────────────────────────────────┘
     toast: bottom-center, auto-fade 3s
     session: modal-lite center, once per AFK
```

Town/park/store/yard: **same panel style** for any overlay; world gets **icon door markers** instead of long labels where possible.

---

## 5. Implementation plan (UX/UI-only PRs)

### UI-1 — Design tokens + shared HUD helpers (**foundation**)
**Ship:** `src/ui/ui_theme.gd` (or similar) with colors, `make_panel()`, `make_title_label()`, `make_body_label()`, button min sizes.  
**Migrate:** habitat panels first (stats, CARE, timer, session, death/empty).  
**Done when:** No one-off StyleBoxFlat copies in habitat for those surfaces.

### UI-2 — Home HUD layout & calm feedback
**Ship:**
- Slim top status bar (name/state, counters, optional day chip).
- Context line bottom (short verb).
- Toast stack bottom-center, **auto-clear 3s**, max 2 lines.
- Session banner: consistent panel, primary/secondary buttons, shorter copy.
- ProgressBar theme (fill color by need severity).
**Done when:** First 10s in house feels uncluttered; toast never permanent.

### UI-3 — CARE & input parity
**Ship:**
- Clickable CARE rows (mouse).
- Optional click-outside or explicit close affordance.
- Cooldown/ready strings already exist — visual progress pip or second line if space.
- Ensure suggest line “Open CARE” deep-link isn’t required; cursor still on suggest.
**Done when:** Fully playable with mouse + keyboard for care.

### UI-4 — Cross-scene chrome pass
**Ship:** Apply tokens to town/park/store/graveyard overlays (labels in panels or icon+short text; buttons themed).  
**Store:** Collapse “Supplies” into a clear **Shop** side card with title “Care points”; adopt modal uses same chrome.  
**Park:** “Play fetch” as themed action chip when leashed near pet, plus one-line bonus hint.  
**Done when:** Screenshots of all 5 places share family resemblance.

### UI-5 — World readability (light)
**Ship:**
- Door markers (icon + 1 word: Town / Yard / House).
- Reduce permanent world Labels; keep interactive prompts in HUD context line.
- Death/empty panels use shared modal style + single primary CTA.
**Done when:** New player finds doors without reading a paragraph.

### UI-6 — First-run & explanation microcopy
**Ship:**
- Tutorial screen aligned with current controls + real-time + ❤ points one-liner.
- First time care points earned: one toast “Earned care points — spend at the Pet Store”.
- Park bonus explained once (“Outdoor bonus active”).
**Done when:** README not required for currency/park bonus discovery.

### UI-7 — Polish pass / regression
**Ship:** Screenshot refresh for README; update `UX-POLISH-CHECKLIST.md`; manual UI checklist (below).  
**Done when:** Visual QA against checklist on 1280×720 and one other size (e.g. 1920×1080).

---

## 6. Explicit non-goals (this plan)

- Full art reboot of town buildings (can be parallel “art” track).
- Reworking sim cooldowns/durations (only display).
- New gameplay systems (quests, second pet).
- Controller full support (note as follow-up).

---

## 7. Success criteria

| Criterion | Measure |
|-----------|---------|
| Hierarchy | Can identify pet state in **2 seconds** from HUD alone |
| Calm | No stale toast after 5s idle |
| Consistency | 5 scenes use same panel/button language |
| Input | CARE completable with mouse only |
| Discoverability | Find backyard + end leash walk without README |
| Density | Home top-left no longer a wall of text |

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| Over-design UI kit delays shipping | UI-1 minimal (colors + 3 constructors only) |
| Breaking care flow while moving HUD | Don’t change care_director; only habitat HUD wiring |
| Hiding useful debug | Keep F3 debug; don’t mix into player HUD |
| Scope creep into full art | World work limited to markers + label reduction |

---

## 9. Plan review (self-critique)

### Strengths
- Grounded in **real surfaces** (habitat HUD chaos, scene inconsistency, toast permanence).
- Reuses existing CARE/stats wins instead of rewriting.
- Ordered so **foundation (tokens) → home (most time) → other scenes**.
- Clear non-goals protect against art/export/sim tangents.

### Weaknesses / open points
1. **How aggressive to hide world labels?** Pure HUD prompts may hurt for players who don’t read bottom bar — keep short world icons.
2. **Session banner vs suggest line** can still duplicate info — UI-2 should define priority (banner once; suggest continuous).
3. **No dedicated mockups** in-plan — first PR should include before/after screenshots as acceptance.
4. **Checklist doc is stale** (lists cooldowns/suggest as open though shipped) — UI-7 must sync it.
5. **Does not include full pixel-art upgrade** — if “looks bad” is mostly *sprites* not *HUD*, R2 art track in release plan must run in parallel; this plan alone won’t fix weak character art.

### Review verdict
**Approve for implementation** with constraints:
- Start **UI-1 + UI-2** only as first PR (or two tight PRs).
- Parallel optional: sprite pass is **separate** from this plan.
- After UI-2, play 15 minutes and re-prioritize UI-3 vs UI-4 based on friction.

### Recommended first execution
**PR “UI kit + home HUD calm”** = UI-1 + UI-2 combined if &lt; ~1k LOC of habitat UI; else split.

---

## 10. Checklist for agents (while implementing)

- [ ] No raw enum toasts  
- [ ] Contrast: light panel + dark text (or inverse), never grey-on-grey  
- [ ] Toast TTL  
- [ ] Mouse targets ≥ ~24px height  
- [ ] 1280×720 layout; no clipped CARE panel  
- [ ] Screenshot in `docs/pr-screenshots/`  
- [ ] Update this plan’s “done when” checkboxes in PR description  

---

*Owner: product polish track. Supersedes ad-hoc UI items in UX-POLISH-CHECKLIST for prioritization; checklist remains for papercut scanning.*
