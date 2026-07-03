# PR Standards — Description + Screenshots + CI

**Rule:** Every pull request has a clear description **and** committed screenshot files. No exceptions.  
**Where to review images:** the PR **Files changed** tab (not a public image host, not required inline embeds in the description).

CI enforces required PR body sections and that screenshot evidence is listed + present in the PR diff. The owner enforces quality when reviewing Files changed.

## Why screenshots always

- UI changes are unreviewable without visuals.
- Sim/backend changes still need proof (test run output, debug F3 overlay, before/after meters, etc.).
- Forces the author to actually run the game/tests before review.

## Required PR body sections

The template in `.github/PULL_REQUEST_TEMPLATE.md` must stay filled:

| Section | Required content |
|---------|------------------|
| Summary | 2–5 sentences: what and why |
| Design / plan link | PR number from design plan (e.g. Design PR 3) + doc path |
| Changes | Bullet list of user-visible and technical changes |
| How to test | Exact steps (editor version, scenes, debug clock if any) |
| Screenshots | List of **committed** image paths under `docs/pr-screenshots/` (and optional `docs/concept-art/`). Reviewer opens **Files changed** |
| Risk / rollback | What could break; how to revert |
| Checklist | All boxes checked honestly |

## Screenshots policy (private repo)

### Do

1. **Commit** image files on the PR branch, usually under:
   - `docs/pr-screenshots/` — evidence for this PR (required ≥1 image file in the PR)
   - `docs/concept-art/` — optional look-targets / design art
2. In the PR body **`## Screenshots`** section, **list those paths** (bullets or plain lines) so CI and reviewers know what to open.
3. Reviewer (and you) look at images in the GitHub **Files changed** tab.

### Do not

- Do **not** use a separate **public** repo or public CDN only to host PR screenshots.
- Do **not** rely on `raw.githubusercontent.com` / private raw URLs for inline embeds in the PR description (GitHub’s proxy cannot load private images there).
- Do **not** leave `## Screenshots` empty or write only “N/A” / `PASTE_OR_DROP_IMAGE_HERE`.
- Relative paths like `![x](docs/foo.png)` in the PR **description** do **not** render as images on GitHub — listing paths for Files changed is the intended workflow.

### Example `## Screenshots` section

```markdown
## Screenshots

Review in **Files changed** (private repo — no public image host):

- `docs/pr-screenshots/pr3-death-catchup-tests.png`
- `docs/pr-screenshots/pr3-debug-hud-dying.png`
```

Optional: add a short caption per file on the same line.

### What to capture by PR type

| PR type | Minimum screenshot set |
|---------|------------------------|
| Bootstrap / tooling | Terminal: tests or `godot --version`; editor/main scene |
| Time / pure sim | Terminal golden test output (pass list); optional debug print |
| Care / death sim | Debug HUD or logs showing stats / DEAD transition |
| Save | Save path + successful load (or test output) |
| Habitat / meters | Full habitat with meters visible |
| Actions / modals | Action bar + toast / modal |
| Pet view | Pet mood states (2+ frames if possible) |
| Day/night | Day + night (2 shots) |
| Burial | Dig progress + completion |
| Graveyard | Wide shot showing many plots / pan; counter HUD |
| Pet store | Species card with feed/play stats visible; adopt flow |
| Juice / balance | Before/after feel evidence if possible |
| Town / WASD / human | Town map, human moving, care choreography frame |

**Multiple images preferred** for multi-scene features.

### Systems-only PRs (no UI yet)

Still required. Commit images such as:

1. Terminal test output (all PASS).
2. Layout / debug print / minimal main scene.

## CI checks (required for merge)

| Check | Purpose |
|-------|---------|
| `pr-body` | Required headings; `## Screenshots` lists ≥1 path to an image under `docs/pr-screenshots/` (or other allowed paths) |
| `pr-screenshots-in-diff` | PR adds/modifies ≥1 image file (`.png` / `.jpg` / `.jpeg` / `.gif` / `.webp`) — typically under `docs/pr-screenshots/` |
| `structure` | Critical paths present (design doc, standards, project layout when expected) |
| `godot-tests` | (When `project.godot` exists) headless unit tests exit 0 |

Local body check:

```bash
./.github/scripts/check_pr_body.sh path/to/pr_body.md
```

## Merge policy (owner)

> **GitHub Free + private repo note:** Classic branch protection / rulesets that *block* merges may require **GitHub Pro**. CI still runs on every PR and must be green before you merge.

Merge **only if**:

1. All required CI checks are **green**.
2. Description is complete and accurate.
3. Screenshot **files** in **Files changed** are present, relevant, and readable.
4. Scope matches the intended design PR / milestone.
5. No unexplained force-push / secret leakage.

Red CI or missing screenshot files → **do not merge**.

## Branch protection (optional / Pro)

```bash
./scripts/enable_branch_protection.sh
```

## Agent checklist

- [ ] Implemented only this PR’s scope
- [ ] Tests added/updated where applicable
- [ ] PR description filled from template
- [ ] **Screenshot image file(s) committed** under `docs/pr-screenshots/`
- [ ] **`## Screenshots` lists those paths** (reviewer uses Files changed)
- [ ] **No public assets repo** used for PR screenshots
- [ ] CI green on the PR
- [ ] Design doc PR plan row referenced
