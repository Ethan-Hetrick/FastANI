# Cached Query Scratch Reuse Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- reused a single `seedHitsL1` vector across cached query fragments
- reused a single `kseq_t seqView` across cached query fragments
- kept the algorithm and output format unchanged

Why this targets item 3:

- the cached sketch-query replay path was rebuilding `seedHitsL1` as a fresh vector for every fragment
- that is repeated scratch-state churn in the exact low-memory multishard mode we care about

Validation:

- multishard `--batch-size 1` output matched baseline exactly

Baseline reference:

- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_batch1_t8.out`

Measured run:

- baseline wall time: `1:02.25`
- experiment wall time: `0:59.14`
- baseline max RSS: `727,320 kB`
- experiment max RSS: `722,792 kB`

Interpretation:

- correctness/output parity was preserved
- the change is localized to scratch-buffer reuse in the cached sketch-query path
- the measured improvement is modest but directionally positive in both wall time and RSS
- this is a reasonable low-risk change to keep because it removes repeated temporary-buffer churn without altering the mapping algorithm
