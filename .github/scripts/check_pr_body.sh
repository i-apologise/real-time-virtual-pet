#!/usr/bin/env bash
# Fail if PR body lacks required sections or Screenshots without an image.
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

# Extract from ## Screenshots until the next level-2 heading (## Foo), allowing ### subheads
screenshots_section="$(
  echo "${body}" | awk '
    BEGIN{IGNORECASE=1}
    /^##[[:space:]]+Screenshots/ {grab=1; next}
    /^##[[:space:]]+/ {if(grab) exit}
    grab {print}
  '
)"

if [[ -z "${screenshots_section//[[:space:]]/}" ]]; then
  fail "Screenshots section is empty. Embed at least one image. See docs/PR_STANDARDS.md"
fi

if ! echo "${screenshots_section}" | grep -Eiq \
  '!\[[^]]*\]\([^)]+\)|<img[[:space:]]|https://[^[:space:]]+\.(png|jpe?g|gif|webp)|user-images\.githubusercontent\.com|github\.com/user-attachments/assets/'; then
  if echo "${screenshots_section}" | grep -Eq 'PASTE_OR_DROP_IMAGE_HERE'; then
    fail "Screenshots still contain PASTE_OR_DROP_IMAGE_HERE — attach a real image."
  fi
  fail "Screenshots section must include at least one image (markdown ![alt](url), <img>, or GitHub attachment URL)."
fi

if echo "${screenshots_section}" | grep -Eq 'PASTE_OR_DROP_IMAGE_HERE'; then
  fail "Replace PASTE_OR_DROP_IMAGE_HERE with a real screenshot."
fi

echo "PR body checks passed (required headings + screenshots with image evidence)."
