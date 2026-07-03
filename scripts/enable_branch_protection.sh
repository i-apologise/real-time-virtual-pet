#!/usr/bin/env bash
# Enable recommended branch protection on main (owner runs once).
set -euo pipefail

REPO="${1:-}"
if [[ -z "${REPO}" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

echo "Applying branch protection on ${REPO} branch main..."

# contexts must match job `name:` fields in ci.yml
gh api -X PUT "repos/${REPO}/branches/main/protection" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "PR Body (description + screenshots)",
      "Repo structure",
      "Godot tests"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": true
}
JSON

echo "Done. PRs to main now require green checks (and conversation resolution)."
echo "Note: PR Body check only runs on pull_request events — required contexts on push-only still need a PR to validate body."
