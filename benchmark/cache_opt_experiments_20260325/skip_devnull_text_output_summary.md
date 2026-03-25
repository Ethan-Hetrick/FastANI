# Skip Devnull Text Output Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- stopped opening `param.outFileName` inside `Map` when the CGI path is already
  collecting structured results via the callback and the file target is `/dev/null`
- skipped formatting and streaming legacy L2 text rows in that same case
- preserved the existing behavior when no callback is installed or when real text
  mapping output is requested

Why this was worth trying:

- the core ANI path redirects the legacy mapping stream to `/dev/null`
- even so, the code was still opening `/dev/null` and formatting every L2 record
- that is unnecessary work in the repeated query path, especially for sketch-backed
  workloads

Validation:

- multishard standard sketch query output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly
- small no-sketch regression output matched baseline exactly

Baseline reference:

- `benchmark/cache_opt_experiments_20260325/noscan_query_t8.out`
- `benchmark/cache_opt_experiments_20260325/noscan_query_batch1_t8.out`
- `benchmark/cache_opt_experiments_20260325/noscan_small_nosketch.out`

Measured sketch runs:

- standard query baseline wall time: `0:18.05`
- standard query experiment wall time: `0:17.28`
- standard query baseline max RSS: `3,317,872 kB`
- standard query experiment max RSS: `3,305,404 kB`
- low-memory query baseline wall time: `0:51.45`
- low-memory query experiment wall time: `0:49.81`
- low-memory query baseline max RSS: `457,040 kB`
- low-memory query experiment max RSS: `456,360 kB`

Interpretation:

- correctness/output parity was preserved
- this is a localized optimization that removes avoidable formatting and `/dev/null`
  write overhead from the CGI execution path
- the measured improvements are modest but consistent, which makes this a good
  low-risk change to keep
