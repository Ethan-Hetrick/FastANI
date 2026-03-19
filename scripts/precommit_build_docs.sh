#!/usr/bin/env bash
set -euo pipefail

mkdocs_bin="${FASTANI_MKDOCS_BIN:-}"

if [[ -n "$mkdocs_bin" ]]; then
  export PATH="$(dirname "$mkdocs_bin"):$PATH"
else
  mkdocs_bin="$(command -v mkdocs || true)"
fi

if [[ -z "$mkdocs_bin" ]]; then
  echo "ERROR: mkdocs not found in PATH. Set FASTANI_MKDOCS_BIN or activate the docs environment." >&2
  exit 1
fi

"$mkdocs_bin" build --strict
