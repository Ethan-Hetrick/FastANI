# FastANI Fork Changelog

## Scope

This changelog summarizes the technical changes made in this fork after diverging from the clean FastANI baseline at commit `491e061` (`Fix typo in README regarding genome formats` in `fastANI_clean/FastANI`).

The intent is to help a technical reviewer understand what changed, why it changed, and which commits are relevant for deeper inspection.

## Summary Of Major Outcomes

- Added persistent reference sketch support so reference-side preprocessing can be reused across runs instead of rebuilt every time.
  Related commits: `7d4f3c2`
- Added richer tabular reporting with optional headers and extended fragment-level summary fields.
  Related commits: `b17b8cc`, `e725145`
- Added sketch-backed memory/runtime control for query execution, first as single-shard low-memory mode and later generalized into `--batch-size`.
  Related commits: `2df35bc`, `f1a5532`, `cbc0d21`, `3ebaf07`
- Reduced repeated low-memory overhead by caching query-side work and skipping unnecessary sketch-load postprocessing.
  Related commits: `f1a5532`, `cbc0d21`
- Improved query-side performance through buffer reuse, reduced copying, cheaper hot loops, and lower synchronization overhead.
  Related commits: `8467983`, `21081f2`, `1053186`, `6d75e89`, `accdccc`, `5b68ea8`, `1a947c3`, `b61a62e`, `792836a`, `eea33e0`, `cc0acd7`, `1641bee`
- Improved sketch/reference build performance through I/O tuning, buffer reuse, uppercase checks, container sizing, and targeted regression fixes.
  Related commits: `0ffcb09`, `ae94e02`, `d60bfb4`, `2b76bba`, `dccf6bf`, `a68d2eb`, `f300362`
- Added manual mapping control for minimizer window size and documented the associated performance/accuracy tradeoff.
  Related commits: `baa5571`, `a7cfea2`
- Built publication-oriented benchmarking and dashboard materials, including repeatable benchmarking scripts, validation outputs, and visual summaries.
  Related commits: `24d5e5b`, `e54bda3`, `3ebaf07`, `e9c4c21`
- Restored sketch-backed output parity and added full all-v-all reporting after fixing sketch metadata and release-mode filtering behavior.
  Related commits: `f613abd`, `c85d035`, `6c4cb6a`

## Correctness And Behavioral Fixes

- Fixed a stale `contigToGenomeId` cache in batched sketch-backed execution and corrected mixed-case sequence normalization for minimizer generation.
  Why: batched sketch runs could silently reuse the wrong contig-to-genome mapping when two shards had the same contig count, and mixed-case sequence beyond the first 4096 bases could bypass uppercasing and alter hashing.
  Validation: added targeted regression tests for batched sketch parity and mixed-case query equivalence in `tests/fastani_tests.cpp`.

- Evaluated and rejected a flat-array replacement for `minimizerPosLookupIndex` on the current benchmark workloads.
  Why: the prototype preserved output parity on the checked sketch-backed paths, but it regressed performance instead of improving it.
  Benchmark summary:
  - half-list sketch query (`standard`): `13.23s` vs prior `8.87s`
  - half-list sketch query (`--batch-size 1`): `57.61s` vs prior `47.62s`
  - full `genome-list.txt` sketch build: `29.87s` vs prior `22.52s`
  - full `genome-list.txt` sketch query was still unfinished after more than `18` minutes, far worse than the prior `483.99s` full sketch-query wall time
    Decision: do not revive this specific “flat hash lookup array” approach without materially different design evidence and new benchmarks showing a clear win.

- Restored the missing query-bucket reduction stage in `computeCGI`, fixing incorrect two-way ANI behavior after earlier optimization work.
  Why: performance work is only useful if the core reciprocal ANI result remains correct.
  Related commit: `e2df7e7`

- Reverted or reworked a few performance changes that were not safe or beneficial in practice.
  Why: some candidate micro-optimizations either regressed performance or were not stable enough to keep.
  Related commits: `78ac943`, `9b8871e`, `accdccc`, `a68d2eb`

- Restored correct sketch-backed release-mode filtering and reference identity handling.
  Why: sketch mode had started reporting different row counts in release builds because reference lengths and file identities were not preserved correctly through the sketch path.
  Related commit: `f613abd`

## Query Mapping Performance

- Removed unnecessary seed-hit copying during L1 mapping.
  Why: avoid repeated vector copies in a hot path.
  Related commit: `8467983`

- Reused iterators and cached state in L2 sliding-window logic.
  Why: reduce repeated tree traversals and pivot recomputation inside tight loops.
  Related commits: `21081f2`, `3eaff47`, `78ac943`, `b280ed8`

- Reused L1 and L2 result buffers across fragments.
  Why: cut allocation churn and repeated container growth during query processing.
  Related commits: `1053186`, `6d75e89`

- Reused `QueryMetaData`, `kseq`-derived temporary state, and query-side mapping buffers.
  Why: reduce repeated setup costs for each fragment and query sequence.
  Related commits: `4da7057`, `9b8871e`, `accdccc`

- Skipped the best-identity scan when `reportAll` is already enabled.
  Why: remove unnecessary selection work when all mappings are retained anyway.
  Related commit: `5b68ea8`

- Replaced critical-section result merging with per-thread accumulation followed by deterministic merge after the parallel region.
  Why: remove synchronization overhead on the mapping/postprocessing path.
  Related commit: `1a947c3`

- Cached contig-to-genome lookup state during CGI postprocessing.
  Why: avoid rebuilding reference contig/genome relationships for every result conversion.
  Related commit: `b61a62e`

- Switched genome length computation to use `kseq` sequence lengths directly instead of `strlen`.
  Why: eliminate redundant string scans during genome-size calculation.
  Related commit: `792836a`

- Tightened hot-loop behavior in minimizer handling and mapping setup.
  Why: reduce overhead in very frequently executed code paths.
  Related commits: `eea33e0`, `cc0acd7`, `1641bee`

## Sketch / Reference Build Performance

- Reserved sketch and index containers up front.
  Why: reduce reallocations while building large sketches.
  Related commit: `0ffcb09`

- Increased zlib read buffering for gzipped FASTA parsing.
  Why: reduce decompression and I/O overhead during large reference scans.
  Related commit: `ae94e02`

- Reused reverse-complement buffers during minimizer generation.
  Why: avoid repeated allocation and large temporary reconstruction.
  Related commit: `d60bfb4`

- Skipped uppercasing when the input sequence is already uppercase.
  Why: avoid a full extra normalization pass when it is not needed.
  Related commit: `2b76bba`

- Reserved and emplaced the minimizer lookup map during sketch load.
  Why: reduce hash table churn while rebuilding lookup structures from serialized sketches.
  Related commit: `dccf6bf`

- Fixed a reference-build regression caused by overly aggressive reserve behavior.
  Why: a later “performance” change roughly doubled reference-build time on real workloads and had to be backed out.
  Related commit: `a68d2eb`

- Added safer reference-size-based pre-sizing for the minimizer table.
  Why: recover some allocation wins without reintroducing the earlier regression.
  Related commit: `f300362`

## Build And Benchmark Configuration

- Added release-grade compile flags.
  Why: ensure performance benchmarking reflects optimized builds rather than debug-like defaults.
  Related commit: `4eb9af8`

## Sketch Databases And Reference Reuse

- Added support for saving and loading reference sketches.
  Why: make reference preprocessing amortizable across repeated query runs instead of paying the full build cost each time.
  Related commit: `7d4f3c2`

- Added compatibility checks between sketch metadata and current run settings.
  Why: prevent accidental reuse of incompatible sketches across different mapping configurations such as mismatched window sizes.
  Related commits: `7d4f3c2`, `baa5571`

## Output And Reporting Features

- Added `--extended-metrics` for fragment-level ANI summary reporting.
  Why: expose more diagnostic detail without changing the core ANI output format unless requested.
  Related commit: `b17b8cc`

- Added `--header` for tabular output.
  Why: improve usability in scripted and downstream tabular workflows.
  Related commit: `e725145`

- Clarified help text and README behavior for visualization, matrix output, sketch usage, and other option interactions.
  Why: several options affect only specific outputs or are incompatible in non-obvious ways.
  Related commits: `1b85092`, `794f443`, `4b40650`, `c0e8091`, `8605dda`

## Memory-Scaling Features For Sketch Queries

- Added a sketch-backed low-memory execution mode that loaded one shard at a time.
  Why: reduce peak RAM for query-side sketch use when the full sketch would otherwise be too large to load at once.
  Related commit: `2df35bc`

- Cached query fragments and their minimizers across shard loads in the low-memory path.
  Why: avoid reparsing the query and rebuilding query-side minimizers for every sketch shard.
  Related commit: `f1a5532`

- Reduced sketch-load overhead by skipping unnecessary full frequency-histogram work when all minimizers are retained.
  Why: remove repeated per-shard post-load work in the low-memory path.
  Related commit: `cbc0d21`

- Generalized the low-memory mode into `--batch-size`.
  Why: expose a continuum between minimum memory and maximum speed instead of a single one-shard-at-a-time mode.
  Related commit: `3ebaf07`

- Added memory-planning heuristics for both query-time batched sketch use and sketch creation.
  Why: make the new runtime/memory controls easier to deploy on HPC and cloud systems.
  Related commit: `e9c4c21`

## Mapping-Parameter Controls

- Added manual `--window-size` control for minimizer sampling.
  Why: make sketch density and runtime/sensitivity tradeoffs directly testable from the CLI.
  Related commit: `baa5571`

- Documented the runtime/accuracy implications of non-default mapping parameters.
  Why: changing mapping knobs can alter results, not just performance, and this needed to be explicit.
  Related commit: `a7cfea2`

## Benchmarking, Validation, And Publication Materials

- Added publication-oriented benchmark assets under `docs/pub`, including the benchmark runner, plotting script, dashboard image, and supporting data files.
  Why: preserve reproducible evidence of performance and memory behavior for review and manuscript preparation.
  Related commit: `24d5e5b`

- Refined installation guidance and dashboard presentation.
  Why: make the optimized build path clearer and improve communication of benchmark results.
  Related commit: `e54bda3`

- Updated the benchmark dashboard to reflect the `--batch-size` model and compare sketch-batch modes back to the original tool.
  Why: the main user-facing tradeoff is now a memory/runtime curve rather than a binary low-memory option.
  Related commit: `3ebaf07`

- Added full all-v-all summary/report generation and folded the larger benchmark into the dashboard.
  Why: capture the original-vs-new comparison at full `genome-list.txt` scale and document the benchmark host, CPU details, and runtime breakdown cleanly.
  Related commit: `c85d035`

- Refreshed the publication dashboard and summary tables after rerunning the current release modes and tightening the validation notes.
  Why: keep the manuscript-facing figures synchronized with the latest benchmark values and the corrected sketch-output path.
  Related commit: `6c4cb6a`

## Benchmark-Derived Technical Observations

- Current no-sketch release-mode runs are measurably faster than the original baseline on the maintained half-list benchmark, with the biggest gain coming from query mapping rather than reference build.
  Evidence path: `benchmark/publication_runs.csv`, `benchmark/plots/publication_key_comparisons.tsv`

- Prebuilt sketch use changes the reference-side cost structure dramatically by replacing rebuild cost with much smaller sketch-load cost.
  Evidence path: `benchmark/plots/publication_key_comparisons.tsv`

- `--batch-size` exposes a practical speed/memory tradeoff:
  - `batch-size=1` greatly lowers peak memory while remaining faster than the original tool
  - `batch-size=5` is still far below original runtime while recovering much of the overhead of one-shard-at-a-time execution
    Evidence path: `benchmark/publication_runs.csv`, `benchmark/plots/publication_summary_by_variant.tsv`

- The corrected sketch-backed full all-v-all workflow is now faster than the original baseline while preserving row-count parity.
  Evidence path: `benchmark/all_v_all_summary.csv`, `benchmark/all_v_all_report.txt`

## Reviewer Notes

- The fork includes both implementation changes and publication/documentation infrastructure. Reviewers focused on runtime behavior should prioritize:
  - sketch save/load and compatibility work
  - query-path performance commits
  - low-memory/batch execution commits
  - regression-fix commits for reference-build performance

- The most important commits for present-day behavior are:
  - `7d4f3c2` for sketch persistence
  - `e2df7e7` for correctness
  - `a68d2eb` for undoing the major reference-build regression
  - `f1a5532`, `cbc0d21`, and `3ebaf07` for the low-memory-to-batched-query evolution
  - `e9c4c21` for operational guidance around memory planning
