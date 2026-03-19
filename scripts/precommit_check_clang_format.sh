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
  base_ref=""

  if upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    if merge_base="$(git merge-base HEAD "$upstream_ref" 2>/dev/null)"; then
      base_ref="$merge_base"
    fi
  fi

  if [[ -z "$base_ref" ]]; then
    for candidate in origin/master master origin/main main; do
      if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
        if merge_base="$(git merge-base HEAD "$candidate" 2>/dev/null)"; then
          base_ref="$merge_base"
          break
        fi
      fi
    done
  fi

  if [[ -n "$base_ref" ]]; then
    mapfile -t tracked_files < <(
      git diff --name-only --diff-filter=ACMRT "$base_ref"...HEAD |
        grep -E '^src/.*\.(c|cc|cpp|cxx|h|hpp)$' || true
    )
  else
    mapfile -t tracked_files < <(git diff --cached --name-only --diff-filter=ACMRT |
      grep -E '^src/.*\.(c|cc|cpp|cxx|h|hpp)$' || true)
  fi

  if [[ ${#tracked_files[@]} -eq 0 ]]; then
    exit 0
  fi

  set -- "${tracked_files[@]}"
fi

"$clang_format_bin" --dry-run --Werror "$@"
