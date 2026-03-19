#!/usr/bin/env bash
set -euo pipefail

mkdocs_bin="${FASTANI_MKDOCS_BIN:-$(command -v mkdocs || true)}"

if [[ -z "$mkdocs_bin" ]]; then
  echo "ERROR: mkdocs not found in PATH. Set FASTANI_MKDOCS_BIN or activate the docs environment." >&2
  exit 1
fi

"$mkdocs_bin" build --strict
