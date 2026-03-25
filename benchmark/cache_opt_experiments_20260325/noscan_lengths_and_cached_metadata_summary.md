# No-Rescan Lengths And Cached Sketch Metadata Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change:

- cached per-sketch contig-to-genome ids in `Sketch`
- cached per-sketch reference contig offset adders in `Sketch`
- cached per-sketch usable genome lengths in `Sketch`
- stopped rescanning query and reference FASTA inputs at the end of a run just to
  rebuild genome lengths for output
- populated query usable lengths from the mapping path and reference usable lengths
  from the already-built sketch metadata

Why this was worth trying:

- CGI and visualization were rebuilding the same reference metadata repeatedly even
  though it is derivable once per sketch
- output generation was rereading genome files after the main analysis had already
  traversed them
- this does not change ANI logic, but it removes repeated bookkeeping and extra I/O

Validation:

- multishard standard sketch query output matched baseline exactly
- multishard `--batch-size 1` output matched baseline exactly
- small no-sketch regression output matched baseline exactly
- one-shard sketch `--batch-size 1 --visualize` run completed successfully and
  produced a non-empty `.visual` sidecar

Baseline references:

- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_t8.out`
- `benchmark/pre_opt_baseline_20260325/new_half_sketch_t8shards_query_batch1_t8.out`
- `benchmark/cache_opt_experiments_20260325/flatbucket_small_nosketch.out`

Measured sketch runs:

- standard query wall time: `0:18.05`
- standard query max RSS: `3,317,872 kB`
- low-memory query wall time: `0:51.45`
- low-memory query max RSS: `457,040 kB`

Interpretation:

- correctness/output parity was preserved in both sketch-backed modes and a small
  no-sketch run
- the main benefit of this change is removing unnecessary end-of-run FASTA rescans
  and repeated reconstruction of sketch-derived lookup metadata
- runtime movement on these spot checks looks small and noisy, which is expected
  because this change is mostly bookkeeping and I/O cleanup rather than hot-loop
  math optimization
