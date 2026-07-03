#!/usr/bin/env bash
# Repo structure gates that always apply; Godot project gates when present.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

need() {
  if [[ ! -e "$1" ]]; then
    echo "::error::Missing required path: $1"
    exit 1
  fi
  echo "OK: $1"
}

need "README.md"
need "CONTRIBUTING.md"
need "docs/PR_STANDARDS.md"
need "docs/design-real-time-virtual-pet.md"
need ".github/PULL_REQUEST_TEMPLATE.md"
need ".github/workflows/ci.yml"
need ".github/scripts/check_pr_body.sh"
need ".gitignore"

if [[ -f "project.godot" ]]; then
  echo "project.godot found — checking Godot layout expectations..."
  need "tests/run_tests.gd"
  # Soft: src or scenes should start existing once bootstrapped
  if [[ ! -d "src" && ! -d "scenes" ]]; then
    echo "::warning::project.godot exists but neither src/ nor scenes/ present yet."
  fi
else
  echo "No project.godot yet — structure check limited to docs/tooling (expected pre-PR1)."
fi

echo "Structure checks passed."
