#!/usr/bin/env bash
# Enable recommended branch protection on main (owner runs once).
# Requires GitHub Pro (or public repo) for private repositories on free plan.
set -euo pipefail

REPO="${1:-}"
if [[ -z "${REPO}" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

echo "Applying branch protection on ${REPO} branch main..."

set +e
out="$(gh api -X PUT "repos/${REPO}/branches/main/protection" \
  --input - 2>&1 <<'JSON'
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
)"
code=$?
set -e

echo "${out}"
if [[ ${code} -ne 0 ]]; then
  echo ""
  echo "Branch protection API failed (exit ${code})."
  echo "On GitHub Free, private repos often cannot enable branch protection (needs Pro or public)."
  echo "CI still runs on PRs — merge only when checks are green and screenshots look good."
  exit "${code}"
fi

echo "Done. PRs to main require green checks."
