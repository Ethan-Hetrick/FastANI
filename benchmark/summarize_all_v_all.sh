#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_CSV="${1:-benchmark/all_v_all_summary.csv}"
OUT_REPORT="${2:-benchmark/all_v_all_report.txt}"

OLD_STDERR="benchmark/all_v_all_old_release.stderr"
NEW_BUILD_STDERR="benchmark/all_v_all_new_sketch_build.stderr"
NEW_QUERY_STDERR="benchmark/all_v_all_new_sketch_query.stderr"
MACHINE_INFO="benchmark/all_v_all_machine_info.txt"
OLD_OUTPUT="benchmark/all_v_all_old_release.out"
NEW_QUERY_OUTPUT="benchmark/all_v_all_new_sketch_query.out"

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

extract_single_metric() {
  local pattern="$1"
  local file="$2"
  grep -m1 "$pattern" "$file" | awk -F': ' '{print $NF}' | awk '{print $1}'
}

extract_single_metric_or_default() {
  local pattern="$1"
  local file="$2"
  local default_value="$3"
  if grep -q "$pattern" "$file"; then
    extract_single_metric "$pattern" "$file"
  else
    printf '%s\n' "$default_value"
  fi
}

sum_metric_lines() {
  local pattern="$1"
  local file="$2"
  grep "$pattern" "$file" | awk -F': ' '{print $NF}' | awk '{sum += $1} END {printf "%.6f\n", sum + 0}'
}

extract_wall_seconds() {
  local file="$1"
  grep 'Elapsed (wall clock) time' "$file" | awk -F': ' '{print $2}' | time_to_seconds
}

extract_timev_field() {
  local label="$1"
  local file="$2"
  grep "$label" "$file" | awk -F': ' '{print $2}' | tr -d '%'
}

append_row() {
  local label="$1"
  local phase_label="$2"
  local output_rows="$3"
  local db_sec="$4"
  local query_sec="$5"
  local post_sec="$6"
  local wall_sec="$7"
  local user_cpu_sec="$8"
  local system_cpu_sec="$9"
  local cpu_percent="${10}"
  local max_rss_kb="${11}"
  local fs_in="${12}"
  local fs_out="${13}"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$label" "$phase_label" "$output_rows" "$db_sec" "$query_sec" "$post_sec" "$wall_sec" \
    "$user_cpu_sec" "$system_cpu_sec" "$cpu_percent" "$max_rss_kb" "$fs_in" "$fs_out" >> "$OUT_CSV"
}

cat > "$OUT_CSV" <<'EOF'
label,phase_label,output_rows,db_sec,query_sec,post_sec,wall_sec,user_cpu_sec,system_cpu_sec,cpu_percent,max_rss_kb,fs_in,fs_out
EOF

old_output_rows="$(wc -l < "$OLD_OUTPUT")"
old_db_sec="$(extract_single_metric 'Time spent sketching the reference' "$OLD_STDERR")"
old_query_sec="$(sum_metric_lines 'Time spent mapping fragments in query' "$OLD_STDERR")"
old_post_sec="$(sum_metric_lines 'Time spent post mapping' "$OLD_STDERR")"
old_wall_sec="$(extract_wall_seconds "$OLD_STDERR")"
old_user_sec="$(extract_timev_field 'User time (seconds)' "$OLD_STDERR")"
old_system_sec="$(extract_timev_field 'System time (seconds)' "$OLD_STDERR")"
old_cpu_percent="$(extract_timev_field 'Percent of CPU this job got' "$OLD_STDERR")"
old_max_rss_kb="$(extract_timev_field 'Maximum resident set size' "$OLD_STDERR")"
old_fs_in="$(extract_timev_field 'File system inputs' "$OLD_STDERR")"
old_fs_out="$(extract_timev_field 'File system outputs' "$OLD_STDERR")"
append_row "Old tool full all-v-all" "Reference build" "$old_output_rows" "$old_db_sec" "$old_query_sec" "$old_post_sec" "$old_wall_sec" "$old_user_sec" "$old_system_sec" "$old_cpu_percent" "$old_max_rss_kb" "$old_fs_in" "$old_fs_out"

new_build_wall_sec="$(extract_wall_seconds "$NEW_BUILD_STDERR")"
new_build_db_sec="$new_build_wall_sec"
new_build_user_sec="$(extract_timev_field 'User time (seconds)' "$NEW_BUILD_STDERR")"
new_build_system_sec="$(extract_timev_field 'System time (seconds)' "$NEW_BUILD_STDERR")"
new_build_cpu_percent="$(extract_timev_field 'Percent of CPU this job got' "$NEW_BUILD_STDERR")"
new_build_max_rss_kb="$(extract_timev_field 'Maximum resident set size' "$NEW_BUILD_STDERR")"
new_build_fs_in="$(extract_timev_field 'File system inputs' "$NEW_BUILD_STDERR")"
new_build_fs_out="$(extract_timev_field 'File system outputs' "$NEW_BUILD_STDERR")"
append_row "New tool sketch build" "Reference sketch build" "0" "$new_build_db_sec" "0" "0" "$new_build_wall_sec" "$new_build_user_sec" "$new_build_system_sec" "$new_build_cpu_percent" "$new_build_max_rss_kb" "$new_build_fs_in" "$new_build_fs_out"

new_query_output_rows="$(wc -l < "$NEW_QUERY_OUTPUT")"
new_query_db_sec="$(extract_single_metric_or_default 'Time spent sketching the reference' "$NEW_QUERY_STDERR" "0")"
new_query_sec="$(sum_metric_lines 'Time spent mapping fragments in query' "$NEW_QUERY_STDERR")"
new_query_post_sec="$(sum_metric_lines 'Time spent post mapping' "$NEW_QUERY_STDERR")"
new_query_wall_sec="$(extract_wall_seconds "$NEW_QUERY_STDERR")"
new_query_user_sec="$(extract_timev_field 'User time (seconds)' "$NEW_QUERY_STDERR")"
new_query_system_sec="$(extract_timev_field 'System time (seconds)' "$NEW_QUERY_STDERR")"
new_query_cpu_percent="$(extract_timev_field 'Percent of CPU this job got' "$NEW_QUERY_STDERR")"
new_query_max_rss_kb="$(extract_timev_field 'Maximum resident set size' "$NEW_QUERY_STDERR")"
new_query_fs_in="$(extract_timev_field 'File system inputs' "$NEW_QUERY_STDERR")"
new_query_fs_out="$(extract_timev_field 'File system outputs' "$NEW_QUERY_STDERR")"
append_row "New tool sketch query" "Sketch load" "$new_query_output_rows" "$new_query_db_sec" "$new_query_sec" "$new_query_post_sec" "$new_query_wall_sec" "$new_query_user_sec" "$new_query_system_sec" "$new_query_cpu_percent" "$new_query_max_rss_kb" "$new_query_fs_in" "$new_query_fs_out"

old_total_wall="$old_wall_sec"
new_total_wall="$(awk -v a="$new_build_wall_sec" -v b="$new_query_wall_sec" 'BEGIN {printf "%.2f\n", a + b}')"
old_total_rss_gib="$(awk -v kb="$old_max_rss_kb" 'BEGIN {printf "%.2f\n", kb / (1024 * 1024)}')"
new_build_rss_gib="$(awk -v kb="$new_build_max_rss_kb" 'BEGIN {printf "%.2f\n", kb / (1024 * 1024)}')"
new_query_rss_gib="$(awk -v kb="$new_query_max_rss_kb" 'BEGIN {printf "%.2f\n", kb / (1024 * 1024)}')"
new_total_cpu_core_sec="$(awk -v u1="$new_build_user_sec" -v s1="$new_build_system_sec" -v u2="$new_query_user_sec" -v s2="$new_query_system_sec" 'BEGIN {printf "%.2f\n", u1 + s1 + u2 + s2}')"
old_total_cpu_core_sec="$(awk -v u="$old_user_sec" -v s="$old_system_sec" 'BEGIN {printf "%.2f\n", u + s}')"

{
  echo "FastANI all-v-all benchmark report"
  echo "Date: $(date -Iseconds)"
  echo
  echo "Scope"
  echo "- Query list: genome-list.txt"
  echo "- Reference list: genome-list.txt"
  echo "- Comparison: old tool full run vs new sketch build + new sketch query"
  echo "- Threads: 20"
  echo "- All benchmark testing so far has been performed on this machine."
  echo
  echo "Machine"
  sed -n '1,40p' "$MACHINE_INFO"
  echo
  echo "Summary"
  echo "- Old tool full run wall time: ${old_total_wall}s"
  echo "- New tool sketch build wall time: ${new_build_wall_sec}s"
  echo "- New tool sketch query wall time: ${new_query_wall_sec}s"
  echo "- New workflow total wall time: ${new_total_wall}s"
  echo "- Old tool peak RSS: ${old_total_rss_gib} GiB"
  echo "- New sketch build peak RSS: ${new_build_rss_gib} GiB"
  echo "- New sketch query peak RSS: ${new_query_rss_gib} GiB"
  echo "- Old tool CPU time (user+sys): ${old_total_cpu_core_sec}s"
  echo "- New workflow CPU time (user+sys): ${new_total_cpu_core_sec}s"
  echo
  echo "Phase timing notes"
  echo "- Old tool DB phase is the in-run reference build."
  echo "- New workflow DB phase is split into sketch build and sketch load."
  echo "- Query and post phases are sums across all per-query timing lines emitted by FastANI."
} > "$OUT_REPORT"

echo "Wrote $OUT_CSV"
echo "Wrote $OUT_REPORT"
