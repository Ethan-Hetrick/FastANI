# FastANI Future Session Context

## Purpose

This document is a reloadable handoff for future chatbot or coding-agent sessions working in this repository. It summarizes the current project state, the technical goals of the fork, the constraints that should guide future work, and the benchmark / publication infrastructure already in place.

## Repository Context

- Repository root: `/scicomp/home-pure/rqu4/PROJECTS/PERSONAL/FastANI`
- Clean upstream reference copy is available at:
  - `/scicomp/home-pure/rqu4/PROJECTS/PERSONAL/FastANI/fastANI_clean/FastANI`
- Current line of work has focused on:
  - sketch-backed execution
  - memory/runtime tradeoffs
  - deterministic performance improvements
  - documentation and publication materials

## High-Level Goals

This fork is intended to improve FastANI operationally, not biologically. The main goals have been:

- reduce repeated reference-side work by reusing reference sketches
- lower query-side memory usage for sketch-backed execution
- expose a practical memory/runtime tradeoff for sketch-backed querying
- improve runtime without changing expected ANI results
- improve install/help/README clarity
- build publication-quality benchmark and reporting materials

## Hard Rules

These are the most important rules for future work.

### 1. Do not change the underlying ANI algorithm casually

The project direction is explicitly conservative:

- no speculative algorithmic changes unless explicitly requested
- no sensitivity/specificity tradeoff changes by default
- no “fast mode” that changes biological behavior unless the user explicitly wants that explored

The preferred optimization style is:

- implementation-level improvements
- allocation/buffer reuse
- less copying
- less redundant parsing/loading
- lower synchronization overhead
- better sketch reuse
- better batching / execution structure

### 2. Preserve determinism

Any retained change should preserve deterministic outputs unless the user explicitly approves otherwise.

That means:

- same rows
- same ANI values
- same output ordering where applicable
- same behavior across repeats for comparable runs

If a change affects result content, it must be treated as a major behavioral change, not a routine optimization.

### 3. Validate with exact output checks

For comparable modes, future work should use exact output validation, typically with `diff -q`.

Important established validation expectations:

- old vs new no-sketch benchmark output should match exactly where expected
- sketch-backed `batch-size=1` should match standard all-shards sketch output exactly
- sketch-backed `batch-size=5` should match standard all-shards sketch output exactly

### 4. Prefer Release-mode benchmarking

Benchmarking should be performed with optimized builds, not profiling/debug builds, unless profiling is the specific goal.

Preferred build commands:

```sh
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build -j
```

The clean/original tool should be rebuilt similarly when doing old-vs-new comparisons.

## Current User-Facing Feature Set Added In This Fork

### Sketch execution and memory control

- `--batch-size` replaces the older `--low-memory` concept
- behavior:
  - omit `--batch-size`: load all sketch shards at once
  - `--batch-size 5`: intermediate memory/runtime tradeoff
  - `--batch-size 1`: minimum-memory query mode

Important CLI constraints:

- `--batch-size` requires `--sketch`
- `--batch-size` is incompatible with `--matrix`
- `--batch-size` is incompatible with `--write-ref-sketch`

### Mapping-parameter control

- `--window-size` was added for manual minimizer window control
- this is documented as a mapping tradeoff, not a harmless performance knob

### Output/documentation improvements

- help text and README were substantially improved
- compatibility notes across parameters were clarified
- install guidance now recommends optimized builds for performance work

## Important Commits

These commits are useful anchors when reloading context:

- `7d4f3c2` `feat: add support for saving and loading reference sketches`
- `a68d2eb` `perf: fix reference build regressions`
- `f300362` `perf: pre-size minimizer table from reference size`
- `f1a5532` `perf: cache query work in low-memory mode`
- `cbc0d21` `perf: reduce low-memory sketch load overhead`
- `3ebaf07` `feat: add sketch batch-size control`
- `e9c4c21` `docs: add memory planning heuristics`
- `3cad783` `docs: summarize fork change history`
- `17e557c` `docs: expand JOSS publication draft`
- `299c6bd` `docs: add draft author metadata`
- `f613abd` `fix: restore sketch output parity`
- `c85d035` `docs: refresh all-v-all benchmark reporting`
- `6c4cb6a` `docs: refresh publication benchmark dashboard`

Also see:

- `docs/CHANGELOG.md`

## Benchmarking Infrastructure

### Primary publication benchmark assets

These are the main files for current performance claims:

- `docs/benchmark/run_publication_benchmarks.sh`
- `docs/benchmark/plot_publication_performance.R`
- `docs/benchmark/BENCHMARK_COMMANDS.md`
- `docs/pub/data/publication_runs.csv`
- `docs/pub/data/publication_validation.txt`
- `docs/pub/data/publication_summary_by_variant.tsv`
- `docs/pub/data/publication_key_comparisons.tsv`
- `docs/pub/images/publication_performance_dashboard.png`
- `docs/pub/pub_draft.md`

Equivalent working copies also exist under `benchmark/`.

### Benchmark workload used for publication materials

Current maintained publication benchmark design:

- query genome:
  - `tests/data/Shigella_flexneri_2a_01.fna`
- reference set:
  - random half-list derived from `genome-list.txt`
  - stored as `benchmark/genome-list_half_random.txt`
  - size used in current runs: 5032 references
- sketch layout:
  - 8-shard sketch
  - prefix: `benchmark/publication_half_t8_sketch`
- repeated runs:
  - 3 replicates per configuration

### Configurations currently benchmarked

- original FastANI, no sketch
- current fork, no sketch
- current fork, sketch query with all shards loaded
- current fork, sketch query with `--batch-size 5`
- current fork, sketch query with `--batch-size 1`

### Metrics captured

From `/usr/bin/time -v` and FastANI logs:

- wall time
- user CPU
- system CPU
- CPU percent
- peak RSS
- filesystem input/output blocks
- major/minor page faults
- voluntary/involuntary context switches
- internal reference-build or sketch-load time
- internal query-mapping time
- internal post-mapping time

### Validation requirement

Comparable modes must be checked with exact output comparison:

- use `diff -q`
- retain validation logs
- publication validation currently stored in:
  - `docs/pub/data/publication_validation.txt`

Also maintain full-scale sketch honesty checks:

- sketch-backed all-v-all output must preserve original-style reference identity and filtering behavior
- release-mode all-v-all row counts should match the original baseline exactly after the sketch metadata fix

## Known Performance Results

These are the current publication-facing headline results relative to the original tool on the maintained benchmark:

- current no-sketch path:
  - about `15.3%` faster overall
- sketch query, all shards:
  - about `15.3x` faster end-to-end
  - about `24.1x` faster sketch setup/load than rebuilding references in-run
- sketch query, `--batch-size 5`:
  - about `88.6%` faster
  - about `26.2%` lower RSS
- sketch query, `--batch-size 1`:
  - about `64.8%` faster
  - about `82.9%` lower RSS

Additional full-scale result:

- full all-v-all (`genome-list.txt` vs `genome-list.txt`) is about `2.13x` faster with the new sketch workflow (`506.51s` total vs `1076.02s` for the original tool)
- corrected sketch-backed all-v-all row counts now match exactly: `1,310,658` old vs `1,310,658` new

If future code changes materially alter these numbers, regenerate the publication benchmark set and dashboard.

## Performance Philosophy Going Forward

### Good future targets

The preferred next optimizations are implementation-level only, for example:

- removing redundant work during sketch load
- reducing allocation churn
- reducing repeated parsing
- improving batching behavior
- better container sizing when it is proven safe
- lowering overhead without altering ANI output

### Avoid by default

- changing minimizer behavior for speed
- changing sketch density by default
- changing thresholds or heuristics that alter reported hits
- adding algorithmically different “fast” modes unless explicitly requested

## Memory Planning Heuristics Already Documented

README now includes user-facing heuristics for:

- query-time sketch batching memory
- sketch-build memory

Those heuristics are planning guidance only. If future work changes memory behavior significantly, update:

- `README.md`
- `docs/pub/pub_draft.md` if the publication narrative depends on the old numbers

## Publication / JOSS Context

JOSS reference material was added under:

- `docs/references/`

Important files:

- `docs/benchmark/FUTURE_SESSION_CONTEXT.md`
- `docs/benchmark/BENCHMARK_COMMANDS.md`
- `docs/references/paper.html`

AI usage note preserved for manuscript work:

- GPT-5.4 code agent was used for the bulk of the initial coding and documentation work
- ChatGPT assistance used during this effort was run with the `high` reasoning setting
- `docs/references/example_paper.html`
- `docs/references/editing.html`
- `docs/references/review_checklist.html`
- `docs/references/review_criteria.html`
- `docs/references/s41467-018-07641-9.pdf`

### Draft paper

Current JOSS-style draft:

- `docs/pub/pub_draft.md`

It currently includes:

- YAML metadata block
- Ethan Hetrick as first author
- Georgia Institute of Technology affiliation
- required JOSS-style sections
- explicit AI usage disclosure
- explicit benchmark/performance evaluation description
- embedded dashboard figure

Still needed before submission:

- final author list
- final affiliations / ORCIDs if desired
- bibliography file (`paper.bib`)
- in-text citations
- acknowledgements / funding text
- final archive DOI/version metadata

## AI Usage Context

The draft and disclosure currently state that:

- GPT-5.4 code agent was used for the bulk of the initial implementation work
- AI-assisted code and text were reviewed by project authors
- code changes were compiled, tested, benchmarked, and validated before retention

Future work should remain consistent with this disclosure style if AI continues to be used.

## Current Documentation Assets

Important maintained docs:

- `README.md`
- `INSTALL.txt`
- `docs/CHANGELOG.md`
- `docs/pub/pub_draft.md`
- `docs/pub/...` benchmark and image assets

If user-facing behavior changes, update documentation in the same session when possible.

## Integration / Regression Testing Expectations

There is not a large formal integration-test suite for all new behavior, so practical regression testing should include:

- build succeeds in Release mode
- `--help` reflects the current CLI
- exact output validation for comparable modes
- benchmark script still runs
- dashboard regeneration still works

For sketch-query changes, verify at minimum:

```sh
./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna --sketch benchmark/publication_half_t8_sketch -t 8 -o /tmp/std.out
./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna --sketch benchmark/publication_half_t8_sketch --batch-size 1 -t 8 -o /tmp/b1.out
./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna --sketch benchmark/publication_half_t8_sketch --batch-size 5 -t 8 -o /tmp/b5.out
diff -q /tmp/std.out /tmp/b1.out
diff -q /tmp/std.out /tmp/b5.out
```

## Practical Notes For Future Agents

- There are many untracked local benchmark/build artifacts in this repo.
  - Do not assume untracked files should be deleted.
  - Avoid destructive cleanup unless explicitly requested.
- The clean upstream copy in `fastANI_clean/FastANI` is useful for:
  - old-vs-new benchmarking
  - baseline code comparison
  - historical behavior checks
- When reviewing history, `docs/CHANGELOG.md` is the fastest high-level summary.
- When reviewing performance claims, `docs/pub/data/` is the source of truth.

## If Starting New Work

Before making major changes, first answer:

1. Is this an implementation optimization or an algorithm change?
2. Can expected outputs remain exactly identical?
3. How will correctness be validated?
4. How will performance be measured in Release mode?
5. Does the README/help/publication material need to change too?

If the answer to (1) is “algorithm change,” stop and get explicit user approval.
