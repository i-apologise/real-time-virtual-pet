# Real-Time Virtual Pet (Godot)

A Tamagotchi-style desktop pet where **real wall-clock time** drives needs, **neglect can kill**, and players **bury pets**, track a **lifetime death counter**, explore a **large graveyard**, and re-adopt from a **Pet Store** with breed stats.

| | |
|--|--|
| **Engine** | Godot **4.3.x** (pin exact patch when project is bootstrapped) |
| **Language** | GDScript |
| **Platform (v1)** | Desktop (macOS primary playtest) |
| **Design** | [`docs/design-real-time-virtual-pet.md`](docs/design-real-time-virtual-pet.md) |
| **PR standards** | [`docs/PR_STANDARDS.md`](docs/PR_STANDARDS.md) |

## Status

**PR1 in progress:** Godot **4.3** project shell, main placeholder scene, autoload stubs, zero-dep test runner, concept art under `docs/concept-art/`.

Design: rev **5.2** (town + human WASD + death-first pet) in `docs/design-real-time-virtual-pet.md`.

## Opening the project

1. Install **Godot 4.3.x** (exact patch pinned when known).
2. Import / open this folder as a project (`project.godot`).
3. Press **F5** — main bootstrap scene.

```bash
# Headless tests (from repo root)
godot --headless --path . -s res://tests/run_tests.gd
```

If `godot` is not on PATH (macOS cask):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tests/run_tests.gd
```

## Concept art (look targets)

See [`docs/concept-art/`](docs/concept-art/) for town, house care, park, store, and graveyard target visuals.


## Contributing / PRs

1. Branch from `main`.
2. Open a **PR with a full description** (template enforced).
3. **Always include screenshots** (UI, debug HUD, terminal test output, or Godot editor as appropriate). CI fails if the Screenshots section is missing or empty.
4. **CI must be green** before merge.
5. Owner merges only after reviewing the PR body + screenshots.

See [Contributing](CONTRIBUTING.md) and [PR standards](docs/PR_STANDARDS.md).

## CI

> **GitHub Free + private repo note:** Classic branch protection / rulesets that *block* merges may require **GitHub Pro** (or a public repo). CI still runs on every PR and must be green before you merge. Until protection is available, treat red CI or missing screenshots as a hard **human** no-merge rule.


GitHub Actions on every PR / push to `main`:

- PR body: description + screenshots checklist
- Repo structure / design doc present
- (Once `project.godot` exists) Godot headless unit tests

## License

TBD (private project).
