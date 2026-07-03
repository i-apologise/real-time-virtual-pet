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

Greenfield. Design approved (rev 5.1). Implementation follows the ordered PR plan in the design doc.

## Contributing / PRs

1. Branch from `main`.
2. Open a **PR with a full description** (template enforced).
3. **Always include screenshots** (UI, debug HUD, terminal test output, or Godot editor as appropriate). CI fails if the Screenshots section is missing or empty.
4. **CI must be green** before merge.
5. Owner merges only after reviewing the PR body + screenshots.

See [Contributing](CONTRIBUTING.md) and [PR standards](docs/PR_STANDARDS.md).

## CI

GitHub Actions on every PR / push to `main`:

- PR body: description + screenshots checklist
- Repo structure / design doc present
- (Once `project.godot` exists) Godot headless unit tests

## License

TBD (private project).
