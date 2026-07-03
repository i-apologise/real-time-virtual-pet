# Agent instructions (this repo)

## PR policy (mandatory)

When opening or updating any pull request:

1. Fill the full PR template (summary, design ref, changes, how to test, risk, checklist).
2. **Commit screenshot image file(s)** under `docs/pr-screenshots/` (and list those paths under `## Screenshots`).
3. Reviewers use the GitHub **Files changed** tab — **do not** use a public mirror/assets repo for PR screenshots.
4. Never leave `## Screenshots` empty or as `PASTE_OR_DROP_IMAGE_HERE` only.
5. Wait for CI green: PR body, screenshot files in diff, structure, Godot tests.
6. Do not tell the user a PR is ready to merge if CI is red or screenshot files are missing.
7. Do not merge unless the user explicitly asks **and** policy is satisfied.

Read `docs/PR_STANDARDS.md` and `CONTRIBUTING.md` before opening PRs.

## Implementation order

Follow `docs/design-real-time-virtual-pet.md` PR plan unless the user reorders.

## Private repo

This project is private. Keep evidence in-repo under `docs/pr-screenshots/`. Do not publish game assets to public pastes or a public screenshot repo unless the user asks.

## User notification (mandatory when opening a PR)

GitHub **will not reliably notify the user** when PRs are created with their own `gh` token.

Whenever you open or update a PR that needs merge:

1. Write/update `docs/NEEDS-YOUR-REVIEW.md` with the PR number, title, and full URL at the top.
2. Append a line to `docs/agent-progress.md`: `NEEDS REVIEW: PR #N — url`
3. Prefer including the URL in any status the parent/watchdog will surface.

Do not assume the user saw the PR.

