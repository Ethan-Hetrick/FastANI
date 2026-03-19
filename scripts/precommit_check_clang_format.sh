#!/usr/bin/env bash
set -euo pipefail

clang_format_bin="${FASTANI_CLANG_FORMAT_BIN:-}"

if [[ -n "$clang_format_bin" ]]; then
  export PATH="$(dirname "$clang_format_bin"):$PATH"
else
  clang_format_bin="$(command -v clang-format || true)"
fi

if [[ -z "$clang_format_bin" ]]; then
  echo "ERROR: clang-format not found in PATH. Set FASTANI_CLANG_FORMAT_BIN or activate the formatter environment." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  exit 0
fi

"$clang_format_bin" --dry-run --Werror "$@"
