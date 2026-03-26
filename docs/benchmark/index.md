# Benchmark Documentation

This section collects the benchmark handoff materials, reproduction commands,
and dashboard-generation workflow used for the current FastANI performance
evaluation work.

Start with:

- [Benchmark commands](BENCHMARK_COMMANDS.md)

Key generated assets live under:

- `benchmark/publication_runs.csv`
- `benchmark/cache_profile_latest/metrics.tsv`
- `benchmark/plots/publication_performance_dashboard.png`
- `benchmark/plots/publication_cache_metrics.tsv`

The current dashboard is centered on the repeated half-list benchmark plus
single-run `perf stat` cache snapshots. The full all-v-all benchmark remains a
separate long-running artifact and is not required to regenerate the main
dashboard.
