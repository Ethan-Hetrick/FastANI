# FastANI Validation and Edge-Case Testing

This document is the living validation log for targeted correctness, robustness,
and edge-case testing in this repository.

It is intended to answer:

- what was tested
- how it was tested
- what latest commit the documented checks were last extended or rechecked on
- what behavior was observed

Unless otherwise noted, commands are run from the repository root.

## Validation batch metadata

- Validation batch date: `2026-03-23`
- Branch tested: `fix/stale-cache-and-mixedcase-correctness`
- Latest commit tested for this document: `c7da4f7`
- Binary used for manual checks: `build/fastANI`

## How to update this document

When adding a new validation entry:

1. Update the top-level latest commit tested if this entry reflects a new check
   or rerun.
2. Record the exact command or minimal reproducible procedure.
3. Record the observed result, not just the intended result.
4. Note whether the behavior is expected, accepted current behavior, or a bug.
5. Keep the test small and reproducible unless the point is a benchmark or
   larger validation study.

## Summary of currently documented validations

| Validation                                    | Result           | Notes                                                            |
| --------------------------------------------- | ---------------- | ---------------------------------------------------------------- |
| Mixed-case sequence normalization             | Pass             | Lowercase sequence beyond base 4096 matched uppercase behavior   |
| Batched sketch shard parity                   | Pass             | `--batch-size 1` matched non-batched output                      |
| FASTA contig-header robustness                | Pass             | Numeric, duplicated, and junky headers did not change ANI output |
| Gzip FASTA parity                             | Pass             | Numeric ANI metrics matched uncompressed input                   |
| CRLF genome-list parsing                      | Pass             | Windows line endings were tolerated in the tested case           |
| Default `stdout` output                       | Pass             | No `-o` matched explicit `-o` payload                            |
| `--header` with `stdout`                      | Pass             | `stdout` output matched file output exactly                      |
| `--average-reciprocals` with extended metrics | Pass             | Row count and header shape behaved as expected                   |
| `--matrix` without `-o`                       | Pass             | Tool failed cleanly with an explicit error                       |
| Blank / whitespace-only lines in list file    | Pass             | Blank lines were ignored in the tested case                      |
| Duplicate genome entries in list file         | Pass with caveat | Duplicate entries are not deduplicated                           |
| Duplicate path warnings                       | Pass             | Exact repeated query/reference paths now warn explicitly         |
| `.visual` output with duplicated contig names | Pass with caveat | Main metrics matched; duplicated headers reduce interpretability |
| Extended-metrics sketch parity                | Pass             | Sketch and no-sketch extended metrics matched                    |
| Mid-range ANI regression fixture              | Pass             | Real archived pair reproduced at `89.8641` ANI                   |
| Sketch MD5 reproducibility sentinel           | Pass             | Two rebuilds produced identical sketch bytes                     |
| Sketch write order invariance                 | Pass             | Reordered reference lists produced the same sketch file          |

## Build prerequisite for the manual checks below

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build --parallel
```

## Targeted regression tests added on this branch

These are repository tests, not one-off manual checks.

### Mixed-case sequence normalization

Purpose:

- verify that lowercase sequence outside the first 4096 bases is normalized
  correctly before hashing

Command:

```sh
cmake -S . -B build-sme-fix -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON
cmake --build build-sme-fix --parallel
ctest --test-dir build-sme-fix --output-on-failure -R "Mixed-case query matches uppercase query"
```

Observed result:

- passed repeatedly

Interpretation:

- mixed-case handling no longer depends on lowercase appearing near the start of
  the sequence

### Batched sketch loading parity

Purpose:

- verify that batched sketch loading does not reuse stale contig-to-genome
  mappings when different sketch shards happen to have the same contig count

Command:

```sh
ctest --test-dir build-sme-fix --output-on-failure -R "Batched sketch loading matches non-batched output"
```

Observed result:

- passed repeatedly

Interpretation:

- batched sketch processing now matches non-batched output in the targeted equal-
  sized-shard regression case

## Manual edge-case validations

### Mid-range ANI regression fixture from archived results

Purpose:

- promote one real historical comparison in the previously under-tested
  middle ANI range into committed test data

Archived source used:

- `benchmark/new_release_nosketch_1v_all.out`
- `benchmark/old_release_1v_all.out`

Selected pair:

- query: `tests/data/Shigella_flexneri_2a_01.fna`
- reference:
  `tests/data/Escherichia_albertii_CP024282.fna`

Why this pair was selected:

- archived outputs agreed exactly on the result
- it sits in the previously under-covered `80-95%` band
- it has substantial support, not just a threshold-level single fragment

Archived and reproduced result:

```text
89.8641    1180    1608
```

Procedure:

```sh
cp /scicomp/reference-pure/Kalamari/Kalamari/Escherichia/albertii/CP024282.fasta \
  tests/data/Escherichia_albertii_CP024282.fna

build/fastANI \
  -q tests/data/Shigella_flexneri_2a_01.fna \
  -r tests/data/Escherichia_albertii_CP024282.fna \
  -o tests/data/shigella_vs_escherichia_albertii_cp024282.txt
```

Observed result:

- rerun matched the archived ANI value exactly
- rerun matched the archived fragment counts exactly

Interpretation:

- this is now the committed mid-range regression fixture for future correctness
  work
- it provides a more meaningful non-`>97%` positive-control case than the
  existing very-high-ANI D4 set alone

### Sketch MD5 reproducibility sentinel

Purpose:

- provide a small serialization sentinel for sketch rebuilds on a fixed test
  reference set
- detect accidental sketch-format or build-order drift in addition to the normal
  output-based regression checks

Important note:

- this is a secondary guardrail only
- matching sketch bytes does not replace output-based correctness tests
- differing sketch bytes do not automatically imply wrong ANI output

Committed inputs:

- `tests/data/sketch_regression_refs.txt`
- `tests/data/sketch_regression_expected.md5`

Reference set:

- `tests/data/D4/2000031001.LargeContigs.fna`
- `tests/data/D4/2000031004.LargeContigs.fna`
- `tests/data/D4/2000031008.LargeContigs.fna`
- `tests/data/D4/2000031009.LargeContigs.fna`
- `tests/data/Escherichia_coli_str_K12_MG1655.fna`
- `tests/data/Shigella_flexneri_2a_01.fna`
- `tests/data/Escherichia_albertii_CP024282.fna`

Deterministic rebuild command:

```sh
build/fastANI \
  --rl tests/data/sketch_regression_refs.txt \
  --write-ref-sketch sketch_regression \
  -t 1
```

Observed validation procedure:

```sh
tmp1=$(mktemp -d /tmp/fastani-sketchcheck1-XXXXXX)
tmp2=$(mktemp -d /tmp/fastani-sketchcheck2-XXXXXX)

build/fastANI --rl tests/data/sketch_regression_refs.txt --write-ref-sketch "$tmp1/test_sketch" -t 1
build/fastANI --rl tests/data/sketch_regression_refs.txt --write-ref-sketch "$tmp2/test_sketch" -t 1

md5sum "$tmp1/test_sketch.0"
md5sum "$tmp2/test_sketch.0"
```

Observed result:

- both rebuilds produced the same MD5:

```text
e354004d848d6a312118457ef5358b67
```

- both sketch files were `71059244` bytes

Interpretation:

- for this fixed input set and single-threaded build recipe, sketch
  serialization was stable across repeated rebuilds
- future changes should preserve this hash unless sketch serialization is
  intentionally changed

### Exact duplicate-path warnings in normal query/reference runs

Purpose:

- warn users when the same query or reference path is supplied multiple times in
  list-based runs

Procedure:

```sh
printf '%s\n%s\n' \
  'tests/data/D4/2000031001.LargeContigs.fna' \
  'tests/data/D4/2000031001.LargeContigs.fna' \
  > /tmp/fastani-dup-query.txt

build-order-check/fastANI \
  --ql /tmp/fastani-dup-query.txt \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  -o /tmp/dup-query.tsv
```

```sh
printf '%s\n%s\n' \
  'tests/data/D4/2000031004.LargeContigs.fna' \
  'tests/data/D4/2000031004.LargeContigs.fna' \
  > /tmp/fastani-dup-ref.txt

build-order-check/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  --rl /tmp/fastani-dup-ref.txt \
  -o /tmp/dup-ref.tsv
```

Observed result:

- duplicate query warning:

```text
WARNING, duplicate query input path appears 2 times: tests/data/D4/2000031001.LargeContigs.fna
```

- duplicate reference warning:

```text
WARNING, duplicate reference input path appears 2 times: tests/data/D4/2000031004.LargeContigs.fna
```

Interpretation:

- normal list-based runs are still allowed to proceed
- the warning is intended to catch accidental duplication in pipelines without
  silently rewriting the user's inputs

### Sketch creation invariance to reference-list order

Purpose:

- verify that `--write-ref-sketch` produces the same sketch file when the same
  reference set is supplied in different orders

Procedure:

```sh
ctest --test-dir build-order-check --output-on-failure -R "Sketch creation is invariant to reference list order"
```

Observed result:

- passed in `133.60 sec`

Artifact check:

```text
d1e1c7691e571629c371c6fc0779463e  build-order-check/sketch-order-a.0
d1e1c7691e571629c371c6fc0779463e  build-order-check/sketch-order-b.0
```

Interpretation:

- sketch writing is now insensitive to reference-list ordering for the tested
  reference set
- canonical ordering is based on a lightweight content-derived key:
  usable genome length, contig count, smallest minimizer hash, and original path
  as a final tie-breaker

### Heuristic duplicate-reference warning during sketch creation

Purpose:

- flag potentially identical reference inputs before writing a sketch

Procedure:

```sh
printf '%s\n%s\n' \
  'tests/data/D4/2000031001.LargeContigs.fna' \
  'tests/data/D4/2000031001.LargeContigs.fna' \
  > /tmp/fastani-dup-refs.txt

build-order-check/fastANI \
  --rl /tmp/fastani-dup-refs.txt \
  --write-ref-sketch /tmp/fastani-dup-sketch \
  -t 1
```

Observed result:

```text
WARNING, sketch creation found potentially identical reference inputs based on (usable_genome_length, contig_count, smallest_minimizer_hash): [tests/data/D4/2000031001.LargeContigs.fna, tests/data/D4/2000031001.LargeContigs.fna]
```

Interpretation:

- this is a practical heuristic warning, not a strict identity proof
- it is designed to catch likely duplicate genomes without depending on genome
  names or contig headers

### FASTA contig-header robustness

Purpose:

- verify that unusual but valid FASTA contig headers do not change core ANI
  output

Input set:

- `tests/data/D4/2000031001.LargeContigs.fna`
- `tests/data/D4/2000031004.LargeContigs.fna`
- `tests/data/D4/2000031008.LargeContigs.fna`
- `tests/data/D4/2000031009.LargeContigs.fna`

Header variants tested:

- numeric-only headers such as `>1`, `>2`
- identical generic headers in every file such as `>1`
- low-information headers with extra trailing text after whitespace

Procedure:

1. Create modified FASTA copies with rewritten contig headers.
2. Run no-sketch comparisons on the original and rewritten FASTA files.
3. Build a sketch from the rewritten FASTA files and compare sketch-backed
   output against the original no-sketch and original sketch output.

Observed result:

- no-sketch numeric headers: match
- no-sketch duplicated headers: match
- no-sketch junky headers: match
- sketch numeric headers: match
- sketch duplicated headers: match
- sketch junky headers: match

Interpretation:

- valid but low-information contig names do not affect the core ANI result in
  the tested workflows
- fully removing FASTA headers was intentionally not tested because that would
  make the file invalid FASTA

### Gzip-compressed FASTA parity

Purpose:

- verify that gzip-compressed FASTA input produces the same ANI metrics as
  uncompressed FASTA input

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-quick-XXXXXX)
cp tests/data/D4/2000031001.LargeContigs.fna "$tmpdir/q.fna"
cp tests/data/D4/2000031004.LargeContigs.fna "$tmpdir/r.fna"
gzip -c "$tmpdir/q.fna" > "$tmpdir/q.fna.gz"
gzip -c "$tmpdir/r.fna" > "$tmpdir/r.fna.gz"

build/fastANI -q "$tmpdir/q.fna" -r "$tmpdir/r.fna" -o "$tmpdir/plain.tsv"
build/fastANI -q "$tmpdir/q.fna.gz" -r "$tmpdir/r.fna.gz" -o "$tmpdir/gzip.tsv"
```

Observed result:

- numeric ANI metrics matched exactly
- the first two columns differed only because the input filenames were different

Observed metric payload:

```text
99.9759    1704    1711
```

Interpretation:

- gzip support is numerically consistent for the tested case

### Windows CRLF genome-list parsing

Purpose:

- verify that a Windows-style `CRLF` list file is accepted in the tested case

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-crlf-XXXXXX)
printf '%s\n%s\n' \
  tests/data/D4/2000031004.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna > "$tmpdir/refs_lf.txt"
python3 - <<'PY'
from pathlib import Path
base = max((p for p in Path('/tmp').iterdir() if p.name.startswith('fastani-crlf-')), key=lambda p: p.stat().st_mtime)
text = (base / 'refs_lf.txt').read_text().splitlines()
(base / 'refs_crlf.txt').write_bytes((''.join(line + '\r\n' for line in text)).encode())
PY

build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_lf.txt" -o "$tmpdir/lf.tsv"
build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_crlf.txt" -o "$tmpdir/crlf.tsv"
```

Observed result:

- output file from the `CRLF` list existed
- payload matched the `LF` list exactly

Interpretation:

- the current parser tolerates `CRLF` in the tested case
- users should still prefer normal Unix line endings for reproducibility

### Default output to `stdout`

Purpose:

- verify that omitting `-o` sends the main ANI table to `stdout`

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-stdout-XXXXXX)
build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  > "$tmpdir/stdout.tsv" 2> "$tmpdir/stdout.err"

build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  -o "$tmpdir/file.tsv" > "$tmpdir/file.stdout" 2> "$tmpdir/file.err"
```

Observed result:

- `stdout` payload matched the explicit `-o` file output exactly

Observed payload:

```text
tests/data/D4/2000031001.LargeContigs.fna	tests/data/D4/2000031004.LargeContigs.fna	99.9759	1704	1711
```

Interpretation:

- default `stdout` output is working as intended for standard tabular output

### `--header` with `stdout`

Purpose:

- verify that the header row is emitted correctly when writing to `stdout`

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-edge5-XXXXXX)
build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  --header > "$tmpdir/stdout.tsv" 2> "$tmpdir/stdout.err"

build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  --header -o "$tmpdir/file.tsv" > "$tmpdir/file.stdout" 2> "$tmpdir/file.err"
```

Observed result:

- `stdout` output matched file output exactly

Observed first line:

```text
Query	Reference	ANI	MatchedFragments	TotalQueryFragments
```

### `--average-reciprocals` with extended metrics

Purpose:

- verify output shape and header content when reciprocal averaging is combined
  with extended metrics

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-recips-XXXXXX)
printf '%s\n%s\n' \
  tests/data/D4/2000031001.LargeContigs.fna \
  tests/data/D4/2000031004.LargeContigs.fna > "$tmpdir/list.txt"

build/fastANI --ql "$tmpdir/list.txt" --rl "$tmpdir/list.txt" --header --extended-metrics -o "$tmpdir/raw.tsv"
build/fastANI --ql "$tmpdir/list.txt" --rl "$tmpdir/list.txt" --header --extended-metrics --average-reciprocals -o "$tmpdir/avg.tsv"
```

Observed result:

- raw data rows: `4`
- averaged data rows: `3`
- averaged header included:
  - `QueryAlignmentFraction`
  - `ReferenceAlignmentFraction`
  - `FragID_F99`
  - `FragID_Stdev`
  - `FragID_Q1`
  - `FragID_Median`
  - `FragID_Q3`

Interpretation:

- reciprocal averaging changed row cardinality as expected and preserved the
  extended-metrics schema

### `--matrix` without `-o`

Purpose:

- verify that modes writing sidecar files fail clearly when no output prefix is
  provided

Procedure:

```sh
build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  -r tests/data/D4/2000031004.LargeContigs.fna \
  --matrix
```

Observed result:

```text
ERROR, --matrix and --visualize require -o/--output because they write sidecar files
```

Interpretation:

- failure mode is explicit and user-readable

### Blank and whitespace-only lines in genome lists

Purpose:

- verify that stray blank lines do not corrupt the tested list-file workflow

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-edge2-XXXXXX)
printf '%s\n%s\n' \
  tests/data/D4/2000031004.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna > "$tmpdir/refs_clean.txt"

cat > "$tmpdir/refs_with_blanks.txt" <<EOF
tests/data/D4/2000031004.LargeContigs.fna


tests/data/D4/2000031008.LargeContigs.fna
EOF

build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_clean.txt" -o "$tmpdir/clean.tsv"
build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_with_blanks.txt" -o "$tmpdir/blanks.tsv"
```

Observed result:

- blank-line output existed
- blank-line payload matched the clean list exactly

Interpretation:

- blank and whitespace-only lines were ignored in the tested case

### Duplicate genome entries in genome lists

Purpose:

- determine whether duplicate list entries are deduplicated automatically

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-edge3-XXXXXX)
printf '%s\n%s\n' \
  tests/data/D4/2000031004.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna > "$tmpdir/refs_nodup.txt"

printf '%s\n%s\n%s\n' \
  tests/data/D4/2000031004.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna > "$tmpdir/refs_dup.txt"

build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_nodup.txt" -o "$tmpdir/nodup.tsv"
build/fastANI -q tests/data/D4/2000031001.LargeContigs.fna --rl "$tmpdir/refs_dup.txt" -o "$tmpdir/dup.tsv"
```

Observed result:

- no-duplicate rows: `2`
- duplicate-list rows: `3`
- payloads did not match because the duplicate entry generated another output row

Interpretation:

- duplicate genome paths are not deduplicated automatically
- this is accepted current behavior and should be documented for users

### `.visual` output with duplicated contig names

Purpose:

- verify that duplicate contig names do not change ANI metrics while checking
  whether `.visual` output remains structurally usable

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-edge4-XXXXXX)
cp tests/data/D4/2000031001.LargeContigs.fna "$tmpdir/query.fna"
cp tests/data/D4/2000031004.LargeContigs.fna "$tmpdir/ref.fna"

python3 - <<'PY'
from pathlib import Path
base = max((p for p in Path('/tmp').iterdir() if p.name.startswith('fastani-edge4-')), key=lambda p: p.stat().st_mtime)
for name in ['query.fna', 'ref.fna']:
    src = base / name
    out = base / name.replace('.fna', '_samehdr.fna')
    with src.open() as fin, out.open('w') as fout:
        for line in fin:
            if line.startswith('>'):
                fout.write('>1\n')
            else:
                fout.write(line)
PY

build/fastANI -q "$tmpdir/query.fna" -r "$tmpdir/ref.fna" -o "$tmpdir/orig.txt" --visualize
build/fastANI -q "$tmpdir/query_samehdr.fna" -r "$tmpdir/ref_samehdr.fna" -o "$tmpdir/samehdr.txt" --visualize
```

Observed result:

- main ANI metrics matched exactly apart from the path columns
- `.visual` line counts matched exactly
- sample `.visual` lines remained structurally valid

Interpretation:

- duplicate contig names do not alter the tested ANI result
- `.visual` remains structurally populated, but duplicated contig names reduce
  human interpretability

### Extended-metrics parity between sketch and no-sketch mode

Purpose:

- verify that sketch-backed execution matches no-sketch execution for the
  extended-metrics columns in a small positive-control panel

Procedure:

```sh
tmpdir=$(mktemp -d /tmp/fastani-edge6-XXXXXX)
printf '%s\n%s\n' \
  tests/data/D4/2000031004.LargeContigs.fna \
  tests/data/D4/2000031008.LargeContigs.fna > "$tmpdir/refs.txt"

build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  --rl "$tmpdir/refs.txt" \
  --extended-metrics --header -o "$tmpdir/nosketch.tsv"

build/fastANI \
  --rl "$tmpdir/refs.txt" \
  --write-ref-sketch "$tmpdir/refsketch" -t 2

build/fastANI \
  -q tests/data/D4/2000031001.LargeContigs.fna \
  --sketch "$tmpdir/refsketch" -t 2 \
  --extended-metrics --header -o "$tmpdir/sketch.tsv"
```

Observed result:

- normalized sketch and no-sketch outputs matched exactly
- compared rows: `2`

Interpretation:

- extended metrics were numerically stable across the tested sketch and
  no-sketch paths

## Current behavior notes worth preserving

- Duplicate genome entries in a query or reference list are not deduplicated
  automatically.
- Blank and whitespace-only lines in list files were tolerated in the tested
  case.
- Valid but non-descriptive contig headers did not affect ANI values in the
  tested workflows.
- Duplicated contig headers can still make `.visual` output harder to interpret
  manually.
- `--matrix` and `--visualize` intentionally require `-o`.

## Suggested next low-cost validations

- invalid list entries pointing to nonexistent files
- very short contigs around the fragment-length threshold
- ambiguous-base and high-`N` input behavior
- gzipped list-driven sketch builds
- larger sketch/no-sketch parity panel with fragmented assemblies
