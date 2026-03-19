#!/usr/bin/env bash
set -euo pipefail

prettier_bin="${FASTANI_PRETTIER_BIN:-}"

if [[ -n "$prettier_bin" ]]; then
  export PATH="$(dirname "$prettier_bin"):$PATH"
else
  prettier_bin="$(command -v prettier || true)"
fi

if [[ -z "$prettier_bin" ]]; then
  echo "ERROR: prettier not found in PATH. Set FASTANI_PRETTIER_BIN or activate the formatter environment." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  mapfile -t tracked_files < <(git ls-files "*.md" "*.yaml" "*.yml")

  if [[ ${#tracked_files[@]} -eq 0 ]]; then
    exit 0
  fi

  set -- --check "${tracked_files[@]}"
fi

"$prettier_bin" "$@"
