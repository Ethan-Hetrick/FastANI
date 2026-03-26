#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="benchmark/eukaryote_apicomplexa"
QUERY_PATH="$(head -n 1 "${WORK_DIR}/apicomplexa_query_1.txt")"
REF_LIST="${WORK_DIR}/apicomplexa_refs_all.txt"
OLD_BIN="fastANI_clean/FastANI/build/fastANI"
NEW_BIN="build/fastANI"
THREADS="${1:-8}"
RAW_CSV="${WORK_DIR}/old_vs_new_1v_all_runs.csv"

if [[ ! -x "$OLD_BIN" ]]; then
  echo "Missing legacy binary: $OLD_BIN" >&2
  exit 1
fi

if [[ ! -x "$NEW_BIN" ]]; then
  echo "Missing current binary: $NEW_BIN" >&2
  exit 1
fi

if [[ ! -f "${WORK_DIR}/apicomplexa_query_1.txt" || ! -f "$REF_LIST" ]]; then
  echo "Missing query/reference lists." >&2
  exit 1
fi

cat > "$RAW_CSV" <<'EOF'
variant,binary_path,threads,query_path,reference_list,output_path,output_rows,internal_db_phase_label,internal_db_phase_sec,internal_query_map_sec,internal_post_map_sec,wall_sec,user_cpu_sec,system_cpu_sec,cpu_percent,max_rss_kb,fs_inputs_blocks,fs_outputs_blocks,major_page_faults,minor_page_faults,voluntary_ctx_switches,involuntary_ctx_switches
EOF

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
  local variant="$1"
  local binary_path="$2"
  local output_path="$3"
  local stderr_path="$4"

  local output_rows db_label db_sec query_sec post_sec wall_sec
  local user_sec system_sec cpu_pct max_rss fs_in fs_out maj_pf min_pf vol_ctx invol_ctx

  output_rows="$(wc -l < "$output_path")"
  db_sec="$(extract_metric 'Time spent sketching the reference' "$stderr_path")"
  query_sec="$(extract_metric 'Time spent mapping fragments in query' "$stderr_path")"
  post_sec="$(extract_metric 'Time spent post mapping' "$stderr_path")"
  db_label="reference_build"

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

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$variant" "$binary_path" "$THREADS" "$QUERY_PATH" "$REF_LIST" "$output_path" "$output_rows" \
    "$db_label" "$db_sec" "$query_sec" "$post_sec" "$wall_sec" "$user_sec" "$system_sec" "$cpu_pct" \
    "$max_rss" "$fs_in" "$fs_out" "$maj_pf" "$min_pf" "$vol_ctx" "$invol_ctx" >> "$RAW_CSV"
}

run_case() {
  local variant="$1"
  local binary="$2"
  local output_path="${WORK_DIR}/${variant}_1v_all.out"
  local stdout_path="${WORK_DIR}/${variant}_1v_all.stdout"
  local stderr_path="${WORK_DIR}/${variant}_1v_all.stderr"

  rm -f "$output_path" "$stdout_path" "$stderr_path"
  /usr/bin/time -v "$binary" -q "$QUERY_PATH" --rl "$REF_LIST" -t "$THREADS" -o "$output_path" > "$stdout_path" 2> "$stderr_path"
  append_csv_row "$variant" "$binary" "$output_path" "$stderr_path"
}

run_case "old_release" "$OLD_BIN"
run_case "new_release" "$NEW_BIN"

echo "Wrote run summary to $RAW_CSV"
