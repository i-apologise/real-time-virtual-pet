#!/usr/bin/env bash
# On pull_request: require at least one image file added/modified in the PR.
set -euo pipefail

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" && -z "${PR_NUMBER:-}" ]]; then
  echo "Not a pull_request event and PR_NUMBER unset — skip screenshot file check."
  exit 0
fi

REPO="${GITHUB_REPOSITORY:-}"
PR="${PR_NUMBER:-${GITHUB_EVENT_PULL_REQUEST_NUMBER:-}}"
if [[ -z "$REPO" || -z "$PR" ]]; then
  # Allow local override: check working tree for docs/pr-screenshots
  if compgen -G "docs/pr-screenshots/*.{png,jpg,jpeg,gif,webp}" > /dev/null 2>&1 \
    || compgen -G "docs/pr-screenshots/*.png" > /dev/null 2>&1; then
    echo "Local mode: found files under docs/pr-screenshots/"
    ls docs/pr-screenshots/ | head
    exit 0
  fi
  echo "::error::Cannot determine PR; set GITHUB_REPOSITORY and PR_NUMBER, or add docs/pr-screenshots/* images locally."
  exit 1
fi

mapfile -t files < <(gh api "repos/${REPO}/pulls/${PR}/files" --paginate --jq '.[].filename')

images=()
for f in "${files[@]}"; do
  if [[ "$f" =~ \.(png|jpe?g|gif|webp)$ ]]; then
    images+=("$f")
  fi
done

if [[ ${#images[@]} -eq 0 ]]; then
  echo "::error::PR must add or modify at least one image file (e.g. docs/pr-screenshots/*.png). Reviewer uses Files changed."
  exit 1
fi

echo "Screenshot / image files in this PR (review in Files changed):"
printf '  - %s\n' "${images[@]}"

# Prefer docs/pr-screenshots for evidence (warn if only elsewhere)
if ! printf '%s\n' "${images[@]}" | grep -q '^docs/pr-screenshots/'; then
  echo "::warning::No files under docs/pr-screenshots/. Prefer committing evidence there (concept-art alone is ok for art-only PRs)."
fi

exit 0
