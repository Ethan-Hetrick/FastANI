#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR="benchmark/eukaryote_apicomplexa"
ZIP_PATH="${WORK_DIR}/apicomplexa_latest.zip"
EXTRACT_DIR="${WORK_DIR}/ncbi_dataset"
ALL_LIST="${WORK_DIR}/apicomplexa_all_genomes.txt"
QUERY_LIST="${WORK_DIR}/apicomplexa_queries_20.txt"
REF_LIST="${WORK_DIR}/apicomplexa_refs_all.txt"
SUMMARY_TXT="${WORK_DIR}/apicomplexa_dataset_summary.txt"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing archive: $ZIP_PATH" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required to extract $ZIP_PATH" >&2
  exit 1
fi

rm -rf "$EXTRACT_DIR"
unzip -q -o "$ZIP_PATH" -d "$WORK_DIR"

mapfile -t genomes < <(
  find "$EXTRACT_DIR/data" -type f \
    \( -name "*_genomic.fna" -o -name "*_genomic.fna.gz" \) \
    | LC_ALL=C sort
)

if [[ ${#genomes[@]} -eq 0 ]]; then
  echo "No genomic FASTA files found under $EXTRACT_DIR/data" >&2
  exit 1
fi

printf '%s\n' "${genomes[@]}" > "$ALL_LIST"
cp "$ALL_LIST" "$REF_LIST"
head -n 20 "$ALL_LIST" > "$QUERY_LIST"

{
  echo "archive: $ZIP_PATH"
  echo "extract_dir: $EXTRACT_DIR"
  echo "total_genomes: ${#genomes[@]}"
  echo "query_count: $(wc -l < "$QUERY_LIST")"
  echo "reference_count: $(wc -l < "$REF_LIST")"
  echo "first_query: $(head -n 1 "$QUERY_LIST")"
  echo "first_reference: $(head -n 1 "$REF_LIST")"
} > "$SUMMARY_TXT"

echo "Prepared Apicomplexa benchmark inputs:"
echo "  all genomes: $ALL_LIST"
echo "  queries:     $QUERY_LIST"
echo "  references:  $REF_LIST"
echo "  summary:     $SUMMARY_TXT"
