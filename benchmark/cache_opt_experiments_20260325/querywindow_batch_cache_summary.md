# Batched Query-Window Cache Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change attempted:

- changed batched sketch mode to build one cached query at a time instead of
  materializing cached query data for the whole query list up front
- reused the same single-query window across the batch loop

Why this was worth trying:

- the current batched sketch path keeps cached minimizers for every query in memory
  at once
- for large query lists, that is the most obvious remaining query-side memory cost

Validation:

- output matched exactly on a 20-query `--batch-size 1` sketch run
- line counts matched exactly

Measured `genome-list_20.txt` query run against a 2-chunk sketch (`--batch-size 1`, `-t 2`):

- baseline wall time: `0:00.89`
- experiment wall time: `0:01.96`
- baseline max RSS: `11,632 kB`
- experiment max RSS: `10,960 kB`
- baseline summed sketch-load time: `0.047961 s`
- experiment summed sketch-load time: `0.670834 s`

Decision:

- not kept

Interpretation:

- the change does reduce peak RSS modestly
- but it forces repeated sketch reload/setup work and more than doubles wall time on
  the checked batched workload
- this confirms that the current all-queries cached-query design is expensive in
  memory but still important for preserving batch-mode throughput
