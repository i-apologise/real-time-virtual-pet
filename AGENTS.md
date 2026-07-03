# Agent instructions (this repo)

## PR policy (mandatory)

When opening or updating any pull request:

1. Fill the full PR template (summary, design ref, changes, how to test, risk, checklist).
2. **Always embed screenshots** under `## Screenshots`. Never leave empty or `PASTE_OR_DROP_IMAGE_HERE`.
   - UI: real game/editor captures.
   - Systems: terminal test output and/or debug HUD — still as **images**.
3. Wait for CI green: `PR Body (description + screenshots)`, `Repo structure`, `Godot tests`.
4. Do not tell the user a PR is ready to merge if CI is red or screenshots are missing.
5. Do not merge unless the user explicitly asks you to merge **and** policy is satisfied.

Read `docs/PR_STANDARDS.md` and `CONTRIBUTING.md` before opening PRs.

## Implementation order

Follow `docs/design-real-time-virtual-pet.md` PR plan unless the user reorders.

## Private repo

This project is private. Do not publish images/secrets to public pastes. Prefer GitHub PR attachments on this private repo.
