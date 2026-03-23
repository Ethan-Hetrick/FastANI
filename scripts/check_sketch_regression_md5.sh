#!/usr/bin/env bash
set -euo pipefail

binary="${1:-${FASTANI_SKETCH_CHECK_BIN:-build/fastANI}}"
refs="tests/data/sketch_regression_refs.txt"
expected_file="tests/data/sketch_regression_expected.md5"

if [[ ! -x "$binary" ]]; then
  echo "ERROR: FastANI binary not found or not executable: $binary" >&2
  exit 1
fi

if [[ ! -f "$refs" ]]; then
  echo "ERROR: sketch regression reference list not found: $refs" >&2
  exit 1
fi

if [[ ! -f "$expected_file" ]]; then
  echo "ERROR: expected sketch MD5 file not found: $expected_file" >&2
  exit 1
fi

tmp1=$(mktemp -d /tmp/fastani-sketch-md5-1-XXXXXX)
tmp2=$(mktemp -d /tmp/fastani-sketch-md5-2-XXXXXX)
cleanup() {
  rm -rf "$tmp1" "$tmp2"
}
trap cleanup EXIT

"$binary" --rl "$refs" --write-ref-sketch "$tmp1/sketch_regression" -t 1 >"$tmp1/stdout" 2>"$tmp1/stderr"
"$binary" --rl "$refs" --write-ref-sketch "$tmp2/sketch_regression" -t 1 >"$tmp2/stdout" 2>"$tmp2/stderr"

actual1=$(md5sum "$tmp1/sketch_regression.0" | awk '{print $1}')
actual2=$(md5sum "$tmp2/sketch_regression.0" | awk '{print $1}')
expected=$(awk '!/^[[:space:]]*#/ && NF {print $1; exit}' "$expected_file")

if [[ "$actual1" != "$actual2" ]]; then
  echo "ERROR: repeated sketch rebuilds produced different MD5 values" >&2
  echo "first rebuild:  $actual1" >&2
  echo "second rebuild: $actual2" >&2
  exit 1
fi

if [[ "$actual1" != "$expected" ]]; then
  echo "ERROR: sketch MD5 does not match expected sentinel" >&2
  echo "expected: $expected" >&2
  echo "actual:   $actual1" >&2
  exit 1
fi

echo "Sketch MD5 sentinel OK: $actual1"
