#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPEATS="${1:-3}"
QUERY="tests/data/Shigella_flexneri_2a_01.fna"
FULL_LIST="genome-list.txt"
HALF_LIST="benchmark/genome-list_half_random.txt"

OLD_BIN="fastANI_clean/FastANI/build/fastANI"
NEW_BIN="build/fastANI"
SKETCH_PREFIX="benchmark/publication_half_t8_sketch"

RAW_CSV="benchmark/publication_runs.csv"
VALIDATION_TXT="benchmark/publication_validation.txt"

mkdir -p benchmark

if [[ ! -f "$HALF_LIST" ]]; then
  shuf "$FULL_LIST" | head -n 5032 > "$HALF_LIST"
fi

cat > "$RAW_CSV" <<'EOF'
scenario,variant,replicate,binary_path,threads,db_mode,query_path,reference_source,output_path,output_rows,internal_db_phase_label,internal_db_phase_sec,internal_query_map_sec,internal_post_map_sec,wall_sec,user_cpu_sec,system_cpu_sec,cpu_percent,max_rss_kb,fs_inputs_blocks,fs_outputs_blocks,major_page_faults,minor_page_faults,voluntary_ctx_switches,involuntary_ctx_switches
EOF

rm -f "$VALIDATION_TXT"
touch "$VALIDATION_TXT"

time_to_seconds() {
  awk -F: '{
    if (NF == 3) {
      print ($1 * 3600) + ($2 * 60) + $3
    } else if (NF == 2) {
      print ($1 * 60) + $2
    } else {
      print $1
    }
  }'
}

extract_metric() {
  local pattern="$1"
  local file="$2"
  grep -m1 "$pattern" "$file" | awk -F': ' '{print $NF}' | awk '{print $1}'
}

append_csv_row() {
  local scenario="$1"
  local variant="$2"
  local replicate="$3"
  local binary_path="$4"
  local threads="$5"
  local db_mode="$6"
  local query_path="$7"
  local reference_source="$8"
  local output_path="$9"
  local stderr_path="${10}"

  local output_rows db_label db_sec query_sec post_sec wall_sec
  local user_sec system_sec cpu_pct max_rss fs_in fs_out maj_pf min_pf vol_ctx invol_ctx

  output_rows="$(wc -l < "$output_path")"
  db_sec="$(extract_metric 'Time spent sketching the reference' "$stderr_path")"
  query_sec="$(extract_metric 'Time spent mapping fragments in query' "$stderr_path")"
  post_sec="$(extract_metric 'Time spent post mapping' "$stderr_path")"

  if grep -q 'loaded sketch from' "$stderr_path"; then
    db_label="sketch_load"
  else
    db_label="reference_build"
  fi

  wall_sec="$(grep 'Elapsed (wall clock) time' "$stderr_path" | awk -F': ' '{print $2}' | time_to_seconds)"
  user_sec="$(grep 'User time (seconds)' "$stderr_path" | awk -F': ' '{print $2}')"
  system_sec="$(grep 'System time (seconds)' "$stderr_path" | awk -F': ' '{print $2}')"
  cpu_pct="$(grep 'Percent of CPU this job got' "$stderr_path" | awk -F': ' '{print $2}' | tr -d '%')"
  max_rss="$(grep 'Maximum resident set size' "$stderr_path" | awk -F': ' '{print $2}')"
  fs_in="$(grep 'File system inputs' "$stderr_path" | awk -F': ' '{print $2}')"
  fs_out="$(grep 'File system outputs' "$stderr_path" | awk -F': ' '{print $2}')"
  maj_pf="$(grep 'Major (requiring I/O) page faults' "$stderr_path" | awk -F': ' '{print $2}')"
  min_pf="$(grep 'Minor (reclaiming a frame) page faults' "$stderr_path" | awk -F': ' '{print $2}')"
  vol_ctx="$(grep 'Voluntary context switches' "$stderr_path" | awk -F': ' '{print $2}')"
  invol_ctx="$(grep 'Involuntary context switches' "$stderr_path" | awk -F': ' '{print $2}')"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$scenario" "$variant" "$replicate" "$binary_path" "$threads" "$db_mode" "$query_path" "$reference_source" \
    "$output_path" "$output_rows" "$db_label" "$db_sec" "$query_sec" "$post_sec" "$wall_sec" "$user_sec" \
    "$system_sec" "$cpu_pct" "$max_rss" "$fs_in" "$fs_out" "$maj_pf" "$min_pf" "$vol_ctx" "$invol_ctx" >> "$RAW_CSV"
}

run_query_case() {
  local scenario="$1"
  local variant="$2"
  local binary="$3"
  local threads="$4"
  local db_mode="$5"
  local reference_source="$6"
  shift 6
  local args=("$@")

  local rep prefix stdout_path stderr_path output_path
  for rep in $(seq 1 "$REPEATS"); do
    prefix="benchmark/${scenario}_${variant}_rep${rep}"
    output_path="${prefix}.out"
    stdout_path="${prefix}.stdout"
    stderr_path="${prefix}.stderr"

    rm -f "$output_path" "$stdout_path" "$stderr_path"
    /usr/bin/time -v "$binary" "${args[@]}" -o "$output_path" > "$stdout_path" 2> "$stderr_path"

    append_csv_row "$scenario" "$variant" "$rep" "$binary" "$threads" "$db_mode" "$QUERY" "$reference_source" "$output_path" "$stderr_path"
  done
}

run_sketch_build_once() {
  local prefix="benchmark/publication_sketch_build_t8"
  local stdout_path="${prefix}.stdout"
  local stderr_path="${prefix}.stderr"
  rm -f "${SKETCH_PREFIX}".* "$stdout_path" "$stderr_path"
  /usr/bin/time -v "$NEW_BIN" --rl "$HALF_LIST" --write-ref-sketch "$SKETCH_PREFIX" -t 8 > "$stdout_path" 2> "$stderr_path"
}

validate_identical_outputs() {
  local lhs="$1"
  local rhs="$2"
  local label="$3"
  if diff -q "$lhs" "$rhs" >/dev/null; then
    printf '%s: MATCH\n' "$label" >> "$VALIDATION_TXT"
  else
    printf '%s: DIFFER\n' "$label" >> "$VALIDATION_TXT"
  fi
}

run_sketch_build_once

run_query_case "half_nosketch_t1" "old_release" "$OLD_BIN" "1" "build_reference_in_run" "$HALF_LIST" -q "$QUERY" --rl "$HALF_LIST" -t 1
run_query_case "half_nosketch_t1" "new_release" "$NEW_BIN" "1" "build_reference_in_run" "$HALF_LIST" -q "$QUERY" --rl "$HALF_LIST" -t 1
run_query_case "half_sketch_t8" "standard" "$NEW_BIN" "8" "load_prebuilt_sketch" "$SKETCH_PREFIX" -q "$QUERY" --sketch "$SKETCH_PREFIX" -t 8
run_query_case "half_sketch_t8" "low_memory" "$NEW_BIN" "8" "load_prebuilt_sketch_low_memory" "$SKETCH_PREFIX" -q "$QUERY" --sketch "$SKETCH_PREFIX" --low-memory -t 8

validate_identical_outputs \
  "benchmark/half_nosketch_t1_old_release_rep1.out" \
  "benchmark/half_nosketch_t1_new_release_rep1.out" \
  "old_vs_new_half_nosketch_rep1"

validate_identical_outputs \
  "benchmark/half_sketch_t8_standard_rep1.out" \
  "benchmark/half_sketch_t8_low_memory_rep1.out" \
  "standard_vs_lowmem_half_sketch_rep1"

for rep in $(seq 2 "$REPEATS"); do
  validate_identical_outputs \
    "benchmark/half_nosketch_t1_old_release_rep1.out" \
    "benchmark/half_nosketch_t1_old_release_rep${rep}.out" \
    "old_release_repeat_${rep}"
  validate_identical_outputs \
    "benchmark/half_nosketch_t1_new_release_rep1.out" \
    "benchmark/half_nosketch_t1_new_release_rep${rep}.out" \
    "new_release_repeat_${rep}"
  validate_identical_outputs \
    "benchmark/half_sketch_t8_standard_rep1.out" \
    "benchmark/half_sketch_t8_standard_rep${rep}.out" \
    "standard_sketch_repeat_${rep}"
  validate_identical_outputs \
    "benchmark/half_sketch_t8_low_memory_rep1.out" \
    "benchmark/half_sketch_t8_low_memory_rep${rep}.out" \
    "low_memory_repeat_${rep}"
done

echo "Wrote raw runs to $RAW_CSV"
echo "Wrote validation results to $VALIDATION_TXT"
