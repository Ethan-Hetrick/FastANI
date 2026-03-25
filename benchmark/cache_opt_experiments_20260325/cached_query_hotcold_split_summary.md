# Cached Query Hot/Cold Split Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- moved cached query fragment names out of `CachedQueryFragment`
- added a cold `fragmentNames` table on `CachedQueryData`
- replaced per-fragment `std::string name` with compact `nameIndex`

Localized size check:

- `CachedQueryFragment`: `72` bytes -> `40` bytes

Why this targets the hot path:

- the cached query path is only used for sketch-backed batched querying
- that is exactly the low-memory multishard mode we care about for heavy workloads
- fragment names are repeated cold metadata and are not part of the mapping logic itself

Validation:

- multishard fast-path output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly

Baseline references:

- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_t8.out`
- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_batch1_t8.out`

Measured runs:

- fast path:
  - baseline wall time: `0:29.50`
  - experiment wall time: `0:20.06`
  - baseline max RSS: `5,269,084 kB`
  - experiment max RSS: `5,272,632 kB`
- low-memory path:
  - baseline wall time: `1:02.25`
  - experiment wall time: `1:01.69`
  - baseline max RSS: `727,320 kB`
  - experiment max RSS: `722,500 kB`

Interpretation:

- correctness/output parity was preserved in both tested modes
- the hot cached fragment record became materially smaller
- the change is most relevant to the low-memory cached-query mode
- measured RSS improvement on this single-query workload is small, which is expected because the query cache is only one part of total memory
- the structural cleanup is still worth keeping because it removes duplicated cold metadata from the hot cached fragment array
