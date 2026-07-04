# Playtest review — ship-and-play checkpoint

**Date:** 2026-07-03  
**Branch context:** post PR #16 (care timer, bathroom clean, leash walk, dual beds)  
**Verdict:** **Good enough to play.** Core loop works. Presentation still early-prototype; polish beats new systems next.

**Evidence screenshots (automated viewport capture):**  
`docs/playtest-review/`

| File | Scene / moment |
|------|----------------|
| `01_habitat_near_pet.png` | Habitat, human near slime on pet bed |
| `02_care_menu_open.png` | CARE menu open (FEED selected) |
| `03_clean_bathroom.png` | Clean staging toward Bath + “Going…” timer |
| `04_after_clean.png` | After clean (toast / state) |
| `05_leash_walk.png` | Walk action + “Walk Xs” timer |
| `06_after_walk.png` | After walk |
| `07_sleep_beds.png` | Sleep staging toward pet bed |
| `08_town.png` | Town map + AI neighbor |
| `09_store.png` | Pet store species cards |
| `10_graveyard.png` | Backyard plot + buried label |
| `11_habitat_final.png` | Habitat return |

Replay capture (optional): `godot --path . -s res://tools/playtest_capture.gd`  
(Shots land in Godot user data `…/Real-Time Virtual Pet/playtest_shots/`; copy into `docs/playtest-review/` if needed.)

---

## What works (keep)

| Area | Notes |
|------|--------|
| **Care loop** | Near pet → **E** → scrollable CARE menu → confirm. Pokémon-like and usable. |
| **Timer** | Center-top countdown during gather / act / leash (“Going…”, “Walk 3.5s”, action name). |
| **Clean → bathroom** | Both move toward Bath; toast “Bathroom time…”. Non-infinite; duration-driven. |
| **Walk + leash** | Multi-leg walk; pet follow; Line2D leash (easy to miss — see polish). |
| **Beds** | “Your bed” (left) + “Pet bed” (cushion); sleep stages at pet bed. |
| **Need bars** | Top-right, not over the pet. Correct placement. |
| **Store** | Clearest screen: species art, stats blurbs, adopt blocked while living pet. |
| **Characters** | Trainer + slime readable at 2× scale. |
| **Sim spine** | Needs, death, deaths/graves counter, burial rules, store adopt gate. |
| **Navigation** | Habitat ↔ Town / Store / Yard; door to town; graveyard leave. |

---

## Issues seen on screen (for later)

### P0 — biggest feel gaps (not blocking play)

1. **Habitat feels empty**  
   Large flat wood floor; furniture is ColorRect blocks, not pixel props. Characters float in empty space. Biggest “toy house” problem.

2. **World labels look like debug UI**  
   Floor text: “Your bed”, “Bath”, “Bowl”, “Pet bed”. Prefer icons, approach-only tooltips, or remove.

3. **CARE menu low contrast**  
   Dark translucent panel, weak text, competes with toast / bed / nav. Store-quality panel would help a lot.

### P1 — readability / HUD

4. **Top-left HUD noise**  
   Deaths line + long control hint + toast + Town/Store/Yard stack. Shorten hints after first session; quieter toasts.

5. **Leash easy to miss**  
   Timer works; leash line thin / actors close. Thicker line, slack, collar/hand cue.

6. **Stats panel polish**  
   Bars OK; labels/panel chrome can feel cramped at some window sizes.

7. **Camera / letterbox**  
   Small room (480×320) + zoom → side gutters. Either framed “handheld” border or slight zoom-out so furniture fills frame.

### P2 — other scenes

8. **Town is prototype blocks**  
   Solid green, path lines, House / Backyard cubes. AI uses same trainer sprite (OK short-term). Needs 2–3 building silhouettes + variety.

9. **Graveyard thin**  
   Functional empty plot + crude buried marker. Wants path, fence, headstone art, ritual juice.

10. **Door to town**  
    Left wall brown stubs barely read as a door.

### P3 — juice & minor logic

11. **No SFX / particles**  
    Care complete is silent; actions feel soft even when OK.

12. **Toast quirk observed in playtest**  
    After a clean cycle: `clean failed: PET_SLEEPING` while pet still looked healthy/awake. Check care vs sleep-state gating later.

13. **Human bed unused in sleep care**  
    Visual only; sleep stages pet bed. Optional: human walk to own bed during sleep choreography.

14. **Bowl / feet / label overlap**  
    Characters standing on labels looks messy.

---

## Suggested polish order (when you resume)

1. Pixel furniture + less empty floor (largest play-hours win)  
2. CARE menu panel style (match store clarity)  
3. HUD cleanup (hints / toast / nav)  
4. Leash readability  
5. Town POI silhouettes  
6. SFX + tiny particles on care done  
7. `PET_SLEEPING` / care edge cases and other small bugs  

**Guidance:** Prefer art + HUD clarity in the house over new systems. Loop is already playable.

---

## How to play (quick)

1. Godot **4.7**, open project, run main scene.  
2. Tutorial once (if not done) → adopt if no pet → habitat/town.  
3. Habitat: **WASD**, near pet **E** → ↑↓ / **Z·Enter** confirm, **X·Esc** cancel.  
4. Try **CLEAN** (Bath), **WALK** (leash + timer), **SLEEP** (pet bed).  
5. Buttons: Town / Store / Yard; left door also → town.  
6. Debug (optional): **F3** overlay; **F7/F8/F9** time skip (see habitat).  

Headless tests:  
`godot --headless --path . -s res://tests/run_tests.gd`  
(Last known: 12/12 pass at this checkpoint.)

---

## Related docs / PRs

- Design: `docs/design-real-time-virtual-pet.md`  
- Presentation roadmap: `docs/design-presentation-quality-roadmap.md`  
- PR standards (screenshots in Files changed): `docs/PR_STANDARDS.md`  
- Open / recent review pointer: `docs/NEEDS-YOUR-REVIEW.md`  
- Care rooms PR: https://github.com/i-apologise/real-time-virtual-pet/pull/16  

---

## One-line summary for later you

> **Playable loop (care, timer, bath clean, leash walk, beds, store, graveyard). Next win is habitat furniture + UI polish, not more features.**

---

## Follow-up shipped: nav + home + dead art (PR #17 era)

See branch `feat/nav-home-backyard-dead-art`:

- **Navigation:** `SceneRouter.go(scene, spawn)` with spawn keys so doors land correctly.
- **Backyard attached to home:** habitat **south door** → backyard; backyard **house door (SW)** / “Enter house” → habitat. Town no longer has a separate Backyard building (was confusing).
- **Town:** House front → home; Park is scenic only (no wrong teleport). Sign notes backyard is through the house.
- **Home polish:** windows, door mats, rug/bed/bowl props, wider camera, clearer door zones.
- **Dead pets:** multi-frame limp → X-eyes (+ spirit) for slime/puppy/owl; looped rest animation.