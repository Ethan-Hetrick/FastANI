# Query Offset Cache Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- cached `queryOffsetAdder` once inside `Map`
- stopped rebuilding query contig offsets inside the visualization writer for every
  `.visual` output emission
- kept the visualization and ANI logic unchanged

Why this was worth trying:

- reference offsets were already cached on the sketch side
- query offsets were still being recomputed in the visualization helper even though
  the query contig metadata had already been collected
- this is a small cold-path cleanup, but it is local and correctness-safe

Validation:

- standard sketch query output matched baseline exactly
- small no-sketch regression output matched baseline exactly
- one-shard `--batch-size 1 --visualize` run produced a `.visual` file identical to
  the previous baseline

Baseline reference:

- `benchmark/cache_opt_experiments_20260325/skipnull_query_t8.out`
- `benchmark/cache_opt_experiments_20260325/skipnull_small_nosketch.out`
- `benchmark/cache_opt_experiments_20260325/cachequery_cleanup_visual_t1.out.visual`

Interpretation:

- correctness/output parity was preserved
- this is a code-cleanliness and redundant-work reduction change rather than a
  hot-loop optimization
- it is still worth keeping because it simplifies visualization bookkeeping and
  makes the output path more internally consistent
