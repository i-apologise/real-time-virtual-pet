#!/usr/bin/env bash
# Fail if PR body lacks required sections or Screenshots without listed committed paths.
set -euo pipefail

BODY_FILE="${1:-}"
if [[ -z "${BODY_FILE}" || ! -f "${BODY_FILE}" ]]; then
  echo "::error::Usage: check_pr_body.sh <body.md>"
  exit 2
fi

body="$(cat "${BODY_FILE}")"

fail() {
  echo "::error::$1"
  exit 1
}

for heading in "Summary" "Changes" "How to test" "Screenshots" "Checklist"; do
  if ! echo "${body}" | grep -Eiq "^#{1,3}[[:space:]]*${heading}"; then
    fail "Missing required heading: '## ${heading}' (or # / ###). See docs/PR_STANDARDS.md"
  fi
done

screenshots_section="$(
  echo "${body}" | awk '
    BEGIN{IGNORECASE=1}
    /^##[[:space:]]+Screenshots/ {grab=1; next}
    /^##[[:space:]]+/ {if(grab) exit}
    grab {print}
  '
)"

if [[ -z "${screenshots_section//[[:space:]]/}" ]]; then
  fail "Screenshots section is empty. List committed image paths (e.g. docs/pr-screenshots/foo.png). See docs/PR_STANDARDS.md"
fi

if echo "${screenshots_section}" | grep -Eq 'PASTE_OR_DROP_IMAGE_HERE'; then
  fail "Replace PASTE_OR_DROP_IMAGE_HERE with committed paths under docs/pr-screenshots/."
fi

# Reject pure N/A with no path evidence
if echo "${screenshots_section}" | grep -Eiq '^[Nn]/[Aa]\.?[[:space:]]*$' \
  && ! echo "${screenshots_section}" | grep -Eiq '\.(png|jpe?g|gif|webp)\b|docs/pr-screenshots/|docs/concept-art/'; then
  fail "Screenshots cannot be only N/A. Commit images and list paths for Files changed review."
fi

# Must list at least one image path (backticked, plain, or markdown link/image)
if ! echo "${screenshots_section}" | grep -Eiq \
  '(docs/pr-screenshots/|docs/concept-art/)[^[:space:])`'\''"]+\.(png|jpe?g|gif|webp)|[^[:space:]]+\.(png|jpe?g|gif|webp)'; then
  fail "Screenshots section must list at least one image path (prefer docs/pr-screenshots/*.png). Reviewer uses Files changed — no public host required."
fi

# Soft-fail message if someone still points only at the old public assets repo without local paths
if echo "${screenshots_section}" | grep -Eiq 'rtvp-pr-assets' \
  && ! echo "${screenshots_section}" | grep -Eiq 'docs/pr-screenshots/'; then
  fail "Do not use public rtvp-pr-assets as the only screenshot evidence. Commit files under docs/pr-screenshots/ and list those paths."
fi

echo "PR body checks passed (headings + Screenshots lists committed image path(s) for Files changed)."
