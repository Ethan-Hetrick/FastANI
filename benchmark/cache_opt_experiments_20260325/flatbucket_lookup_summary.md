# Flat Bucket Payload Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- replaced each `minimizerPosLookupIndex` bucket payload from a standalone
  `std::vector<MinimizerMetaData>` with a compact `(offset, count)` span
- stored all bucket payload elements in one flat contiguous
  `minimizerPosLookupData` vector
- kept the lookup semantics and sketch on-disk payload format unchanged

Why this targets item 4:

- the sketch-query hot path pays for millions of bucket lookups
- the old representation carried a full vector object per hash bucket, which
  adds indirection and scattered payload storage
- flattening those payloads keeps the algorithm the same while making the
  lookup payload denser and more contiguous in memory

Validation:

- multishard sketch query output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly
- tiny sketch build/load smoke test matched no-sketch output exactly

Baseline references:

- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_t8.out`
- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_batch1_t8.out`

Measured multishard runs:

- standard query baseline wall time: `0:29.50`
- standard query experiment wall time: `0:14.60`
- standard query baseline max RSS: `5,269,084 kB`
- standard query experiment max RSS: `3,323,908 kB`
- low-memory query baseline wall time: `1:02.25`
- low-memory query experiment wall time: `0:50.60`
- low-memory query baseline max RSS: `727,320 kB`
- low-memory query experiment max RSS: `457,448 kB`

Smoke test:

- built a fresh small sketch from `tests/data/sketch_regression_refs.txt`
- queried `tests/data/D4/2000031001.LargeContigs.fna` against that sketch
- sketch-backed output matched the no-sketch output exactly (`4` rows)

Interpretation:

- correctness/output parity was preserved in both the multishard query path and
  a fresh sketch build/load round trip
- the change directly densifies the per-minimizer lookup payloads rather than
  only trimming metadata around them
- the measured standard and low-memory query improvements are large enough to
  justify keeping this representation, though the whole branch still combines
  several prior cache-locality cleanups
