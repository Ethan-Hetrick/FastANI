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

"$prettier_bin" --write "$@"
