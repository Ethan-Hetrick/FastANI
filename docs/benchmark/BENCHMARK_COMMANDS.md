# Benchmark Commands

## Release Builds

Build the current fork in Release mode:

```sh
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build -j
```

Build the clean/original FastANI baseline similarly:

```sh
cd fastANI_clean/FastANI
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build -j
cd -
```

## Publication Benchmark Suite

Run the maintained publication benchmark set:

```sh
bash docs/benchmark/run_publication_benchmarks.sh
```

Run with a custom repeat count:

```sh
bash docs/benchmark/run_publication_benchmarks.sh 5
```

This writes the benchmark CSV and validation log under `benchmark/`.

## Dashboard Regeneration

Regenerate the publication dashboard and summary tables:

```sh
Rscript docs/benchmark/plot_publication_performance.R \
  benchmark/publication_runs.csv \
  benchmark/plots \
  benchmark/publication_validation.txt
```

## Sketch Query Validation

Validate that batched sketch execution matches the all-shards sketch output:

```sh
./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna \
  --sketch benchmark/publication_half_t8_sketch \
  -t 8 -o /tmp/std.out

./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna \
  --sketch benchmark/publication_half_t8_sketch \
  --batch-size 5 \
  -t 8 -o /tmp/b5.out

./build/fastANI -q tests/data/Shigella_flexneri_2a_01.fna \
  --sketch benchmark/publication_half_t8_sketch \
  --batch-size 1 \
  -t 8 -o /tmp/b1.out

diff -q /tmp/std.out /tmp/b5.out
diff -q /tmp/std.out /tmp/b1.out
```

## Key Output Files

- `benchmark/publication_runs.csv`
- `benchmark/publication_validation.txt`
- `benchmark/plots/publication_summary_by_variant.tsv`
- `benchmark/plots/publication_key_comparisons.tsv`
- `benchmark/plots/publication_performance_dashboard.png`
