# Cache Profile Latest

This directory keeps the latest compact cache/perf summary used by the main
performance dashboard.

Workload:

- query: `tests/data/Shigella_flexneri_2a_01.fna`
- references: `benchmark/genome-list_half_random.txt`
- threads: `1`
- profiler: `/scicomp/home-pure/rqu4/bin/perf stat`

Key takeaways from the current snapshot:

- Fixed current no-sketch keeps the faster query phase (`21.849 s` vs old `34.080 s`) while bringing the reference-side build back in line (`51.437 s` lookup-index build).
- Current no-sketch IPC is now `0.695` vs old `0.643`.
- Current no-sketch L2 demand miss rate is `60.5%` vs old `59.0%`.
- Current no-sketch LLC load miss rate is `80.3%` vs old `92.3%`.
- Fixed sketch-backed query remains the most cache-efficient query mode here, with IPC `0.982` and L2 demand miss rate `21.7%`.

The machine-readable table is in `metrics.tsv`.
