# Design: Presentation & Care Interaction Quality Roadmap

| Field | Value |
|-------|-------|
| **Status** | Draft for implementation sequencing |
| **Date** | 2026-07-03 |
| **Depends on** | Current main (sprite sim, tutorial, adopt-first) |
| **Goal** | Pokemon-readable characters, clear death, action-specific animation, E-to-care interaction |

---

## Overview

The game has a working real-time pet sim and a basic overworld. Players still report that **death poses look unconvincing**, **care animations are generic**, and **care UX should be interact-driven (E near pet)** rather than always-on hotkeys. This document plans iterative improvements without another infinite review loop—each phase is a shippable PR.

---

## Goals

1. **Dead pet reads as “a creature that has died”** (side-lying body, X-eyes or closed lids, limp limbs, optional small spirit) — not a flattened color blob.
2. **Every care action has a distinct human + pet animation** (feed bowl, play ball, brush, sleep Zzz, wake wave, dig shovel).
3. **Care opens only via E when near the pet** (menu/hotkeys after interact), matching RPG interact patterns.
4. **Longer-term art quality** path toward hand-authored sheets / Aseprite pipeline while procedural/PNG assets improve each PR.

## Non-Goals (this roadmap)

- 3D models, spine skeletal animation
- Multiplayer, paid art marketplace integration
- Changing death/sim balance (unless a PR explicitly says so)

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interact model | **Near pet → E → care menu → action** | Standard RPG; avoids accidental care while walking |
| Animation source | **32×32 PNG action strips** first; Aseprite sheets later | Ship readable motion now |
| Death presentation | **Dedicated dead pose + spirit** per species | Emotional clarity |
| Y-sort + collision | Keep current collision layers | Already prevents walk-through |
| PR strategy | **Small follow-ups**: (1) E-care+dead+anims now (2) art pass (3) juice/SFX | User asked for multiple PRs until good |

---

## Current gaps (as of post-PR12)

| Area | Problem | Target |
|------|---------|--------|
| Dead art | Weak / flat | Side body, X eyes, spirit mote |
| Care anims | Reused idle/walk | Per-action trainer + pet reaction frames |
| Care UX | 1–6 always when near | **E opens menu**; then 1–6 |
| Style consistency | Mixed 16/32 era | Stick to 32×32 PNG atlas |
| Feedback | Thin toast only | Action SFX + particles later |

---

## Interaction design (authoritative for next build)

```
Player walks near pet (dist ≤ NEAR_PET_DIST)
  → bubble: needs + condition tag
  → hint: "Press E to care"
Player presses E
  → Care menu visible (Feed / Walk / Play / Clean / Sleep / Wake / Close)
Player selects action (click or 1–6)
  → CareDirector: walk to pet → play action anims (human+pet) → apply CareActions
  → menu closes; pet condition anim updates
Esc or leave range → menu closes
```

Dead pet: no care menu; only Dig Grave hold UI.

---

## Animation matrix (MVP of this roadmap PR)

| Action | Human | Pet |
|--------|-------|-----|
| Feed | Bowl forward frames | Eat / mouth open |
| Walk | Play-like energetic motion (or future leash frames) | Bounce / play |
| Play | Ball raise/throw | Chase/play |
| Clean | Brush stroke | Sparkle / clean |
| Sleep | Zzz gesture | Sleep lids |
| Wake | Wave | Idle wake |
| Dig | Shovel | (dead only, no pet anim) |

Timing: ~1.0s staged action after arrival.

---

## Dead pet art spec

Per species (`slime` / `puppy` / `owl`):

1. Body **horizontal / collapsed** (not standing idle recolor)
2. **X eyes** or fully closed lids
3. Limbs/tail **limp**
4. Optional **small white spirit** above (classic soft cue)
5. Darker, desaturated palette

---

## Implementation phases (PRs)

### PR-NOW (this branch) — E-care + dead + action frames
- New dead PNGs; action trainer frames; slime reaction frames
- Habitat: E toggles care menu; hotkeys only when open
- CareDirector uses action anim names
- Design doc (this file)

### PR-NEXT — Species action parity + burial stage
- Puppy/owl dedicated act frames (not happy-idle remap)
- Dig choreography walks to grave marker in house or yard
- Short SFX stubs (feed/play/clean)

### PR-LATER — Art pipeline
- Aseprite source files in `art/`
- Sprite atlas import settings
- Optional palette swap for day/night
- UI skin (9-patch panels matching pixel style)

### PR-LATER — Juice
- Particles (hearts, crumbs, water drops)
- Screen flash on death reveal
- Camera slight punch on care complete

---

## Risks

| Risk | Mitigation |
|------|------------|
| Menu + E conflict with town door E | Priority: pet interact if near pet, else door |
| Anim finish race double-apply care | CareDirector single-state machine + token |
| Asset load failures | Fallback magenta texture + CI load test |

---

## Validation

1. Fresh boot → tutorial → adopt → house  
2. Near pet: stats bubble; **no** care bar until **E**  
3. E → menu → Feed: human bowl anim + pet eat anim + hunger up  
4. F8 death: **dead pose** reads as deceased; dig still works  
5. Tests green  

---

## Open questions (for you)

1. Prefer **radial menu** vs **bottom bar** after E? (Current: bottom bar)  
2. Walk action: stay indoor “stretch” or auto-route to park later?  
3. Spirit mote on death: keep soft/cute or remove for realism?

---

*End of roadmap. PR-NOW implements the interaction + dead/action art baseline.*
