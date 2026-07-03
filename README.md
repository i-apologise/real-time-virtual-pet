# Real-Time Virtual Pet (Godot)

A Tamagotchi-style desktop pet where **real wall-clock time** drives needs, **neglect can kill**, and players **bury pets**, track a **lifetime death counter**, explore a **large graveyard**, and re-adopt from a **Pet Store** with breed stats. You are an **invincible human** in a small town (WASD).

| | |
|--|--|
| **Engine** | Godot **4.3+** (tested **4.7.stable**) |
| **Language** | GDScript |
| **Platform (v1)** | Desktop (macOS primary playtest; Windows/Linux export later) |
| **Version** | **0.1.0** |
| **Design** | [`docs/design-real-time-virtual-pet.md`](docs/design-real-time-virtual-pet.md) rev 5.2 |
| **PR standards** | [`docs/PR_STANDARDS.md`](docs/PR_STANDARDS.md) |

## Play (MVP loop)

1. Install Godot 4.3+ and open this folder (`project.godot`).
2. Press **F5** — boots into **Habitat**.
3. **Adopt** (empty-slot quick adopt or **Pet Store** cards with breed stats).
4. **Care**: Feed / Walk / Play / Clean / Sleep / Wake (cooldowns; rejects when dead/asleep).
5. **Town**: WASD move, approach POI, **E** to enter house / store / graveyard / park.
6. **Death**: neglect long enough (or debug **F8** +3d) → hold **Dig Grave** ~3s → graveyard headstone → re-adopt.
7. Only **pets** have needs/death. **Humans are invincible.**

### Debug keys (editor / debug builds)

| Key | Action |
|-----|--------|
| **F3** | Toggle debug overlay (stats, hold, counters, clock offset) |
| **F7** | Advance sim clock **+1 hour** |
| **F9** | Advance **+2 hours** |
| **F8** | Advance **+3 days** (expect DEAD from full defaults) |

## Headless tests

```bash
godot --headless --path . --import || true
godot --headless --path . -s res://tests/run_tests.gd
```

## Validation bar (0.1.0)

See design doc validation list. Core automated coverage:

- Catch-up / death matrix (2h alive, 3d DEAD, multi-zero, clock stalls)
- Care cooldowns / diminish / dead reject
- Save schema v2 roundtrip
- Adopt / burial counter separation (`total_pets_died` vs `total_graves_dug`)
- Scene load smoke (habitat, store, graveyard, town)

Manual: F8 death → dig grave → re-adopt different species; town WASD; day/night wash.

## Export notes

- Desktop export presets not committed (create in editor: macOS / Windows / Linux).
- Disable debug overlay reliance in release (`OS.is_debug_build()` gates offset in spirit; F-keys still in habitat for 0.1.0 playtest — strip or gate in a follow-up if shipping store builds).
- Saves: `user://saves/pet_save.json` (+ `.bak`).

## Contributing / PRs

1. Branch from `main`.
2. Full PR template + **committed** screenshots under `docs/pr-screenshots/`.
3. CI green before merge.

See [Contributing](CONTRIBUTING.md) and [PR standards](docs/PR_STANDARDS.md).

## License

TBD (private project).
