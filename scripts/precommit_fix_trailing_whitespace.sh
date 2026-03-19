#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  exit 0
fi

python3 - "$@" <<'PY'
from pathlib import Path
import re
import sys

for name in sys.argv[1:]:
    path = Path(name)
    if not path.is_file():
        continue
    text = path.read_text()
    fixed = re.sub(r"[ \t]+(?=\r?\n)", "", text)
    if fixed != text:
        path.write_text(fixed)
PY
