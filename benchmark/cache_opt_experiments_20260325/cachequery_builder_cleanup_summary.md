# Cached Query Builder Cleanup Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- removed cached fragment-name storage from `CachedQueryData`
- stopped copying cached query metadata into `Map` unless `--visualize` is enabled
- removed the per-fragment temporary `std::string` sequence copy during cached-query
  construction
- kept cached fragment length, minimizers, and mapping semantics unchanged

Why this was worth trying:

- cached sketch-query mode was still carrying fragment names even though the mapping
  path no longer uses them
- cached query building was still allocating a temporary fragment string for every
  fragment even though minimizers can be computed from a view into the existing
  sequence buffer
- both issues sit in the exact low-memory cached-query path we have been optimizing

Validation:

- multishard `--batch-size 1` output matched baseline exactly
- one-shard `--batch-size 1 --visualize` sketch query completed successfully and
  produced a non-empty `.visual` sidecar

Baseline reference:

- `benchmark/cache_opt_experiments_20260325/flatbucket_query_batch1_t8.out`

Measured multishard run:

- baseline wall time: `0:50.60`
- experiment wall time: `0:49.83`
- baseline max RSS: `457,448 kB`
- experiment max RSS: `455,668 kB`

Interpretation:

- correctness/output parity was preserved in the real cached-query multishard path
- the change removes more dead cached state and one per-fragment allocation from the
  cached query builder
- the measured improvement is modest but directionally positive in both wall time
  and RSS, and the simplification itself is worthwhile
