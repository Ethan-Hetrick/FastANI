# Compact CGI Callback Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- captured `MappingResult_CGI` records directly from the mapping callback
- stopped first materializing a full `skch::MappingResult` vector only to convert it
  immediately during `computeCGI()`
- kept ANI and postprocessing logic unchanged

Why this was worth trying:

- the CGI path only consumes the compact mapping fields needed for ANI aggregation
- building the larger legacy mapping objects first adds avoidable allocation and copy
  overhead in the repeated query path
- this is a local structural cleanup that preserves the existing algorithm

Validation:

- multishard standard sketch query output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly
- small no-sketch regression output matched baseline exactly

Baseline reference:

- `benchmark/cache_opt_experiments_20260325/skipnull_query_t8.out`
- `benchmark/cache_opt_experiments_20260325/skipnull_query_batch1_t8.out`
- `benchmark/cache_opt_experiments_20260325/queryoffset_small_nosketch.out`

Measured sketch runs:

- standard query baseline wall time: `0:17.28`
- standard query experiment wall time: `0:16.25`
- standard query baseline max RSS: `3,305,404 kB`
- standard query experiment max RSS: `3,323,588 kB`
- low-memory query baseline wall time: `0:49.81`
- low-memory query experiment wall time: `0:48.52`
- low-memory query baseline max RSS: `456,360 kB`
- low-memory query experiment max RSS: `455,448 kB`

Interpretation:

- correctness/output parity was preserved
- this reduces callback-path bookkeeping in the repeated sketch query path
- wall time improved modestly in both measured sketch modes
- RSS stayed essentially flat, with a tiny decrease in `--batch-size 1` and a tiny
  increase in the standard sketch path
