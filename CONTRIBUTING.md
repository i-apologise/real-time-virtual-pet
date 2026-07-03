# Contributing

This is a **private** project. Work happens via **pull requests** only — no direct pushes to `main` for feature work once branch protection is enabled.

## Branching

- `main` — protected, always green, shippable after each merged PR in the plan.
- Feature branches: `pr-NN-short-slug` or `feat/short-slug` matching the design PR plan.

## Pull request requirements (non-negotiable)

Every PR **must** include:

1. **Description** — what changed, why, how to test, risk, design/PR plan reference.
2. **Screenshots** — at least one image (or short clip as GIF/WebM). **Never omit.**
   - UI PRs: in-game or editor captures of the new UI.
   - Systems/sim PRs: terminal test output, debug overlay, or Godot remote/scene tree proving the change.
   - Docs-only PRs: screenshot of rendered doc section or file tree is acceptable; still required.
3. **CI green** — all required checks pass.
4. **Human review** — owner merges only if checks are green **and** the PR looks good (description + screenshots reviewed).

Use the GitHub PR template (auto-filled). Details: [`docs/PR_STANDARDS.md`](docs/PR_STANDARDS.md).

## Local checks (when Godot exists)

```bash
# After project.godot exists — example
godot --headless --path . -s res://tests/run_tests.gd
```


> **GitHub Free + private repo note:** Classic branch protection / rulesets that *block* merges may require **GitHub Pro** (or a public repo). CI still runs on every PR and must be green before you merge. Until protection is available, treat red CI or missing screenshots as a hard **human** no-merge rule.

## Never do

- Merge with red CI
- Open a PR without committed screenshot files + paths listed in `## Screenshots`
- Use a separate public repo only to host PR screenshots
- Force-push to `main`
- Skip the design plan sequence without an explicit decision to re-order

## Agent / automation note

Agents **must** commit screenshot files under `docs/pr-screenshots/` and list those paths in the PR body. Reviewers use **Files changed**. Do **not** create or use a public assets repo for PR images. Forgetting screenshot files is a process failure.
