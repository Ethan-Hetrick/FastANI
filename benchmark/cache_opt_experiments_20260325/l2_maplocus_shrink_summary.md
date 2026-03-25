# L2 MapLocus Shrink Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- removed `optimalStart` and `optimalEnd` from `skch::Map::L2_mapLocus_t`
- these iterators were written in the hot L2 loop but never read afterward

Localized size check:

- `L2_mapLocus_t`: `32` bytes -> `12` bytes

Validation:

- multishard fast-path output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly

Baseline references:

- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_t8.out`
- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_batch1_t8.out`

Measured runs:

- fast path:
  - baseline wall time: `0:29.50`
  - experiment wall time: `0:23.18`
  - baseline max RSS: `5,269,084 kB`
  - experiment max RSS: `5,270,656 kB`
- low-memory path:
  - baseline wall time: `1:02.25`
  - experiment wall time: `1:11.56`
  - baseline max RSS: `727,320 kB`
  - experiment max RSS: `722,584 kB`

Interpretation:

- correctness/output parity was preserved in both tested modes
- the type shrink is real and localized
- runtime movement was mixed across the two query modes and should be treated as noisy until replicated
- this is still a reasonable change to keep because it removes dead state from a hot query-side structure at very low risk
