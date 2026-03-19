#!/usr/bin/env bash
set -euo pipefail

cp README.md docs/index.md
cp INSTALL.txt docs/INSTALL.txt
cp LICENSE docs/LICENSE

mkdir -p docs/images
cp -r images/. docs/images/

mkdir -p docs/tests
cp -r tests/data docs/tests/data

python3 - <<'PY'
from pathlib import Path

index = Path("docs/index.md")
text = index.read_text()
text = text.replace('src="docs/images/', 'src="images/')
text = text.replace("(docs/images/", "(images/")
text = text.replace(
    "[Troubleshooting and support](#troubleshooting-and-support)",
    "[Troubleshooting](#troubleshooting)",
)
text = text.replace(
    "[`tests/data`](tests/data)",
    "`tests/data`",
)
index.write_text(text)
PY
