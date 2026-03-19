#!/usr/bin/env bash
set -euo pipefail

build_dir="${FASTANI_PRECOMMIT_BUILD_DIR:-build-precommit}"
jobs="${FASTANI_PRECOMMIT_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

cmake -S . -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" -j "$jobs" --target fastANI
