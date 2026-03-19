#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  exit 0
fi

python3 - "$@" <<'PY'
from pathlib import Path
import sys

for name in sys.argv[1:]:
    path = Path(name)
    if not path.is_file():
        continue

    data = path.read_bytes()
    if not data:
      continue

    fixed = data.rstrip(b"\r\n") + b"\n"
    if fixed != data:
        path.write_bytes(fixed)
PY
