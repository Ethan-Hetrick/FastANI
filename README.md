# FastANI

[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%20v2.0-blue.svg)](LICENSE)
[![BioConda Install](https://img.shields.io/conda/dn/bioconda/fastani.svg?style=flag&label=BioConda%20install)](https://anaconda.org/bioconda/fastani)
[![GitHub Downloads](https://img.shields.io/github/downloads/ParBLiSS/FastANI/total.svg?style=social&logo=github&label=Download)](https://github.com/ParBLiSS/FastANI/releases)
[![codecov](https://codecov.io/gh/ParBLiSS/FastANI/branch/master/graph/badge.svg?token=B7YFZ56BW2)](https://codecov.io/gh/srirampc/FastANI)

FastANI is a tool for fast, alignment-free computation of whole-genome Average Nucleotide Identity (ANI). ANI is commonly used to quantify similarity between microbial genomes. FastANI supports both complete and draft assemblies and is designed for high-throughput genome comparison workloads.

The method follows the same general ANI workflow described by [Goris et al. 2007](http://www.ncbi.nlm.nih.gov/pubmed/17220447), but avoids expensive full-sequence alignments and instead uses [Mashmap](https://github.com/marbl/MashMap) as the MinHash-based mapping engine. More details on the method, accuracy, and large-scale applications are described in "[High Throughput ANI Analysis of 90K Prokaryotic Genomes Reveals Clear Species Boundaries](https://doi.org/10.1038/s41467-018-07641-9)".

## Download and compile

Clone the repository and follow [`INSTALL.txt`](INSTALL.txt) to build the project.

Prebuilt dependency-free binaries for Linux and macOS are also available from the [releases page](https://github.com/ParBliSS/FastANI/releases).

## Quick start

Print the help page:

```sh
./build/fastANI --help
```

Compute ANI for a single query genome against a single reference genome:

```sh
./build/fastANI -q QUERY_GENOME -r REFERENCE_GENOME -o output.txt
```

Compute ANI for a single query genome against many references:

```sh
./build/fastANI -q QUERY_GENOME --refList references.txt -o output.txt
```

Compute ANI for many queries against many references:

```sh
./build/fastANI --queryList queries.txt --refList references.txt -o output.txt
```

Use sketch-backed querying to avoid rebuilding the reference database each time:

```sh
./build/fastANI --refList references.txt --write-ref-sketch reference_sketch
./build/fastANI -q QUERY_GENOME --sketch reference_sketch -o output.txt
```

Use low-memory sketch-backed querying when RAM is limited:

```sh
./build/fastANI -q QUERY_GENOME --sketch reference_sketch --low-memory -o output.txt
```

Show the installed version:

```sh
./build/fastANI --version
```

## Input files

- `-q, --query` expects a single query genome in FASTA or FASTQ format, optionally gzip-compressed.
- `-r, --ref` expects a single reference genome in FASTA or FASTQ format, optionally gzip-compressed.
- `--queryList` expects a text file with one query genome path per line.
- `--refList` expects a text file with one reference genome path per line.
- `--sketch` expects the prefix of a previously written reference sketch database and is used instead of `--ref` or `--refList`.
- `--write-ref-sketch` writes a reference sketch database and exits; it requires `--ref` or `--refList` and does not use query input.

## Parameter reference

### Input options

- `-q, --query`: single query genome in FASTA/FASTQ format, optionally gzip-compressed.
- `-r, --ref`: single reference genome in FASTA/FASTQ format, optionally gzip-compressed.
- `--ql, --queryList`: text file listing query genome paths, one per line.
- `--rl, --refList`: text file listing reference genome paths, one per line.
- `--sketch`: load a previously written reference sketch prefix instead of rebuilding references from `--ref` or `--refList`.

### Output options

- `-o, --output`: write the main tabular ANI results to this file.
- `--write-ref-sketch`: write a reference sketch database and exit. This requires `--ref` or `--refList` and does not use query input.
- `--matrix`: also write ANI values to `<output>.matrix` as a lower-triangular PHYLIP-style matrix. This is incompatible with `--low-memory`.
- `--visualize`: also write fragment mappings to `<output>.visual`. This works for pairwise and multi-genome runs, though the bundled plotting example is oriented toward one pair at a time.
- `--extended-metrics`: add extra fragment-level ANI summary fields to the main tabular output only.
- `--header`: add a header row to the main tabular output only.

### Mapping parameters

Warning: these parameters can change reported ANI values, hit counts, sensitivity, and runtime. Non-default settings should be treated as a different analysis configuration, not as a harmless performance tweak.

- `-k, --kmer`: k-mer size used by the mapper. The current implementation expects values up to `16`; larger values can change sensitivity and should be used cautiously.
- `--window-size`: manually set the minimizer window size instead of using FastANI's internally recommended value.
- `--fragLen`: fragment length used for query fragmentation.
- `--minFraction`: minimum shared fraction required before trusting ANI for a genome pair.
- `--maxRatioDiff`: upper bound on the allowed difference between reference hash-density statistics used during mapping.

Guidance:

- Larger `--window-size` values reduce minimizer density, which usually lowers runtime and memory use but can change ANI estimates and which hits are reported.
- In local benchmarking on one Shigella-against-sketch workload, `--window-size 32` reduced query runtime noticeably relative to the default sketch settings, but also changed reported results enough that it should be treated as an accuracy/sensitivity tradeoff.
- More aggressive values such as `--window-size 36` or `48` may speed runs further, but they produced larger result drift in the same benchmark and are harder to justify without workload-specific validation.
- Changing `--fragLen` can also affect sensitivity and reported matches; it is not only a performance knob.
- If you care about comparability to published FastANI defaults or to earlier runs, prefer the recommended/default mapping parameters.

### Execution options

- `-t, --threads`: number of threads to use.
- `--low-memory`: load one sketch bin at a time during sketch-backed querying. This requires `--sketch` and is incompatible with `--matrix` and `--write-ref-sketch`.
- `-s, --sanityCheck`: run the built-in sanity check mode.
- `-h, --help`: print the command-line help page.
- `-v, --version`: print the program version.

### Compatibility notes

- `--sketch` is used instead of `--ref` or `--refList`.
- `--write-ref-sketch` requires reference input and does not use query input.
- `--low-memory` requires `--sketch` and cannot be combined with `--matrix` or `--write-ref-sketch`.
- `--header` and `--extended-metrics` affect only the main tabular output, not `.matrix` or `.visual` sidecar files.
- `--visualize` works for pairwise and multi-genome runs, but the bundled `scripts/visualize.R` example is pairwise-oriented.
- Sketches written with one `--window-size` are not interchangeable with runs using a different `--window-size`.
- More generally, sketches should be reused only when the mapping configuration is compatible with the configuration used when the sketch was written.

## Common workflows

### 1 vs 1 with extended metrics

```sh
./build/fastANI -q query.fa -r reference.fa --extended-metrics -o output.txt
```

### 1 vs all from a prebuilt sketch

```sh
./build/fastANI -q query.fa --sketch reference_sketch -o output.txt
```

### 1 vs all from a prebuilt sketch with visualization output

```sh
./build/fastANI -q query.fa --sketch reference_sketch --visualize -o output.txt
```

### 1 vs all from a prebuilt sketch with lower memory usage

```sh
./build/fastANI -q query.fa --sketch reference_sketch --low-memory -o output.txt
```

Notes:

- `--low-memory` is available only with `--sketch`.
- `--low-memory` is incompatible with `--matrix` and `--write-ref-sketch`.
- `--low-memory` trades runtime for lower peak memory usage by loading one sketch bin at a time.
- `--window-size` sets the minimizer window size manually instead of using FastANI's internally recommended value.
- Larger `--window-size` values generally reduce minimizer density and can speed up runs at the cost of sensitivity.
- Non-default mapping parameters, especially `--window-size`, can change reported ANI values and which hits appear in the output.
- `--visualize` can be used in pairwise and multi-genome runs; it writes fragment mappings to `<output>.visual`.
- The bundled `scripts/visualize.R` example is intended for pairwise plotting, even though `.visual` output can contain multiple genome pairs.

### All vs all with matrix output

```sh
./build/fastANI --queryList queries.txt --refList references.txt --matrix -o output.txt
```

## Output

The main output is a tab-delimited file. Each row reports:

1. query genome
2. reference genome
3. ANI estimate
4. number of bidirectional fragment mappings
5. total query fragments

Alignment fraction with respect to the query genome can be estimated as:

```text
bidirectional fragment mappings / total query fragments
```

If `--header` is used, the tabular output includes a header row.
It does not change the `.matrix` or `.visual` sidecar files.

If `--extended-metrics` is used, the output includes additional fragment-level ANI summary fields.
These additional fields are added only to the main tabular output.

If `--matrix` is used, FastANI also writes a second file with the `.matrix` extension containing ANI values arranged as a [phylip-formatted lower triangular matrix](https://www.mothur.org/wiki/Phylip-formatted_distance_matrix).

If `--visualize` is used, FastANI also writes a `.visual` file containing fragment-level mappings for each reported query/reference comparison.

No ANI output is reported for genome pairs whose ANI is much lower than 80%. For those comparisons, amino-acid-level approaches such as [AAI](http://enve-omics.ce.gatech.edu/aai/) are more appropriate.

## Example run

Two small test genomes are available under [`tests/data`](tests/data).

Example:

```sh
./build/fastANI \
  -q tests/data/Shigella_flexneri_2a_01.fna \
  -r tests/data/Escherichia_coli_str_K12_MG1655.fna \
  -o fastani.out
```

Example output:

```text
tests/data/Shigella_flexneri_2a_01.fna	tests/data/Escherichia_coli_str_K12_MG1655.fna	97.7507	1303	1608
```

This means the ANI estimate between the two genomes is `97.7507`, with `1303` reciprocal fragment mappings out of `1608` total query fragments.

## Sketch databases

FastANI can persist reference sketches and reuse them across runs.

Write a sketch database:

```sh
./build/fastANI --refList references.txt --write-ref-sketch reference_sketch
```

Reuse the sketch database:

```sh
./build/fastANI --queryList queries.txt --sketch reference_sketch -o output.txt
```

This is especially useful when the same reference database is queried repeatedly.

Compatibility notes:

- When `--sketch` is used, reference sketches are loaded from disk instead of rebuilding them from `--ref` or `--refList`.
- `--low-memory` is only meaningful for sketch-backed querying and cannot be combined with `--matrix` or `--write-ref-sketch`.
- `--window-size` changes the sketching parameters, so sketch files written with one window size are not interchangeable with runs using a different window size.
- Changing mapping parameters can change results, so sketch-backed runs should only be compared directly when they use compatible sketch and mapping settings.

## Visualization of conserved regions

FastANI can emit reciprocal mapping information for visualization in pairwise or multi-genome comparisons.

```sh
./build/fastANI -q B_quintana.fna -r B_henselae.fna --visualize -o fastani.out
Rscript scripts/visualize.R B_quintana.fna B_henselae.fna fastani.out.visual
```

The generated `.visual` file can be plotted with the provided R script and [genoPlotR](https://cran.r-project.org/web/packages/genoPlotR/index.html). See also [issue #100](https://github.com/ParBLiSS/FastANI/issues/100).

For multi-genome runs, the `.visual` file may contain mappings for many genome pairs; in practice, the provided plotting workflow is most straightforward for one pair at a time.

<p align="center">
<img src="https://i.postimg.cc/kX77DHcr/readme-ANI.jpg" height="350"/>
</p>

## Parallelization

FastANI supports multi-threading via `-t, --threads`.

For even larger workloads, users can also divide a large reference database into chunks and run multiple FastANI processes in parallel. The repository includes helper scripts for splitting databases for that purpose.

## Known behavior

### Asymmetry in ANI computation

FastANI can report slightly different ANI values for a genome pair `(A, B)` depending on which genome is used as the query and which is used as the reference. See [issue #36](https://github.com/ParBLiSS/FastANI/issues/36) for an example.

In practice, this difference is usually small. When `--matrix` output is requested, FastANI reports a single value per genome pair corresponding to the average of both directions.

## Quality guidance

Input quality matters. It is a good idea to quality-check both reference and query assemblies before running large analyses. As a practical rule of thumb, assemblies with N50 values below 10 Kbp may lead to weaker ANI estimates.

## Troubleshooting and support

Bug reports, feature requests, and general feedback are welcome through the [GitHub issue tracker](https://github.com/ParBLiSS/FastANI/issues).
