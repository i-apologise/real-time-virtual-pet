# PR Standards — Description + Screenshots + CI

**Rule:** Every pull request has a clear description **and** screenshots. No exceptions.  
CI enforces the template sections; the owner enforces quality.

## Why screenshots always

- UI changes are unreviewable without visuals.
- Sim/backend changes still need proof (test run output, debug F3 overlay, before/after meters, save file snippet as image, etc.).
- Forces the author to actually run the game/tests before review.

## Required PR body sections

The template in `.github/PULL_REQUEST_TEMPLATE.md` must stay filled:

| Section | Required content |
|---------|------------------|
| Summary | 2–5 sentences: what and why |
| Design / plan link | PR number from design plan (e.g. Design PR 3) + doc path |
| Changes | Bullet list of user-visible and technical changes |
| How to test | Exact steps (editor version, scenes, debug clock if any) |
| Screenshots | **≥1 image** embedded with markdown `![desc](url)` **or** GitHub drag-drop attachments that render as images in the body |
| Risk / rollback | What could break; how to revert |
| Checklist | All boxes checked honestly |

### Screenshots — what to capture by PR type

| PR type | Minimum screenshot set |
|---------|------------------------|
| Bootstrap / tooling | Terminal: tests or `godot --version`; editor project open |
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

**Multiple images preferred** for multi-scene features (before/after, open/closed, day/night).

### Embedding images

Preferred:

```markdown
## Screenshots

![Habitat meters after 2h catch-up](https://user-images.githubusercontent.com/.../meters.png)

![Unit test run green](https://user-images.githubusercontent.com/.../tests.png)
```

GitHub also accepts pasted images in the web UI; they must appear **under the Screenshots heading**.

### Systems-only PRs (no UI yet)

Still required. Example acceptable set:

1. Screenshot of `tests/run_tests.gd` output (all PASS).
2. Screenshot of relevant code path or F3 debug overlay in a minimal main scene.

Do **not** write “N/A” without an image. If the environment cannot capture UI, capture **terminal + file tree** as images — not empty text.

## CI checks (required for merge)

| Check | Purpose |
|-------|---------|
| `pr-body` | PR description contains required headings including `## Screenshots` with at least one image markdown or HTML `<img` |
| `structure` | Critical paths present (design doc, standards, project layout when expected) |
| `godot-tests` | (When `project.godot` exists) headless unit tests exit 0 |

Local simulation of PR body check:

```bash
./.github/scripts/check_pr_body.sh path/to/pr_body.md
```

## Merge policy (owner)

> **GitHub Free + private repo note:** Classic branch protection / rulesets that *block* merges may require **GitHub Pro** (or a public repo). CI still runs on every PR and must be green before you merge. Until protection is available, treat red CI or missing screenshots as a hard **human** no-merge rule.


Merge **only if**:

1. All required CI checks are **green**.
2. Description is complete and accurate.
3. Screenshots are present, relevant, and readable (not a black screen unless intentional).
4. Scope matches the intended design PR / milestone.
5. No unexplained force-push / secret leakage.

Red CI or missing screenshots → **do not merge**. Request changes.

## Branch protection (recommended settings on GitHub)

After first push, enable on `main`:

- Require a pull request before merging
- Require status checks to pass: `PR Body (description + screenshots)`, `Repo structure`, `Godot tests` (when available)
- Require branches to be up to date (optional)
- Do **not** allow admin bypass casually

Script helper (run once as owner with `gh`):

```bash
./scripts/enable_branch_protection.sh
```

## Agent checklist (copy into implementation prompts)

- [ ] Implemented only this PR’s scope
- [ ] Tests added/updated where applicable
- [ ] PR description filled from template
- [ ] **Screenshots captured and embedded under `## Screenshots`**
- [ ] CI green on the PR
- [ ] Design doc PR plan row referenced
