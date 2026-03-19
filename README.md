# FastANI

[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%20v2.0-blue.svg)](LICENSE)
[![BioConda Install](https://img.shields.io/conda/dn/bioconda/fastani.svg?style=flag&label=BioConda%20install)](https://anaconda.org/bioconda/fastani)
[![GitHub Downloads](https://img.shields.io/github/downloads/ParBLiSS/FastANI/total.svg?style=social&logo=github&label=Download)](https://github.com/ParBLiSS/FastANI/releases)
[![codecov](https://codecov.io/gh/ParBLiSS/FastANI/branch/master/graph/badge.svg?token=B7YFZ56BW2)](https://codecov.io/gh/srirampc/FastANI)

FastANI is a tool for fast, alignment-free computation of whole-genome Average Nucleotide Identity (ANI). ANI is commonly used to quantify similarity between microbial genomes. FastANI supports both complete and draft assemblies and is designed for high-throughput genome comparison workloads.

The method follows the same general ANI workflow described by [Goris et al. 2007](http://www.ncbi.nlm.nih.gov/pubmed/17220447), but avoids expensive full-sequence alignments and instead uses [Mashmap](https://github.com/marbl/MashMap) as the MinHash-based mapping engine. More details on the method, accuracy, and large-scale applications are described in "[High Throughput ANI Analysis of 90K Prokaryotic Genomes Reveals Clear Species Boundaries](https://doi.org/10.1038/s41467-018-07641-9)".

## Start here

- [Install FastANI](INSTALL.txt)
- [Quick start](#quick-start)
- [Choose a workflow](#choose-a-workflow)
- [Reference guide](#reference-guide)
- [Input options](#input-options)
- [Output options](#output-options)
- [Mapping parameters](#mapping-parameters)
- [Execution options](#execution-options)
- [Troubleshooting and support](#troubleshooting-and-support)

## Installation

Clone the repository and follow [`INSTALL.txt`](INSTALL.txt) to build the project.

Prebuilt dependency-free binaries for Linux and macOS are also available from the [releases page](https://github.com/ParBliSS/FastANI/releases).

After installation, the executable is available as `fastANI`.
If you are running directly from the build tree without installing, use `build/fastANI`.

## Quick start

Inspect the installed CLI:

```sh
fastANI --help
fastANI --version
```

Compute ANI for a single query genome against a single reference genome:

```sh
fastANI -q QUERY_GENOME -r REFERENCE_GENOME -o output.txt
```

Compute ANI for a single query genome against many references:

```sh
fastANI -q QUERY_GENOME --refList references.txt -o output.txt
```

Compute ANI for many queries against many references:

```sh
fastANI --queryList queries.txt --refList references.txt -o output.txt
```

## Choose a workflow

Use plain query/reference inputs when:
- you are running one-off analyses
- you do not plan to reuse the same reference database repeatedly
- you want FastANI to rebuild reference data directly from the supplied FASTA/FASTQ inputs

Use sketch-backed workflows when:
- you will query the same reference set repeatedly
- reference build time matters
- you want explicit control over RAM usage with `--batch-size`

### 1 vs 1

```sh
fastANI -q query.fa -r reference.fa -o output.txt
```

### 1 vs 1 with extended metrics

```sh
fastANI -q query.fa -r reference.fa --extended-metrics -o output.txt
```

### 1 vs many

```sh
fastANI -q query.fa --refList references.txt -o output.txt
```

### Many vs many

```sh
fastANI --queryList queries.txt --refList references.txt -o output.txt
```

### Many vs many with matrix output

```sh
fastANI --queryList queries.txt --refList references.txt --matrix -o output.txt
```

## Reference guide

### Input options

| Parameter | Default | Description | Typical use |
| --- | --- | --- | --- |
| `-q, --query` | `null` | Single query genome in FASTA/FASTQ format, optionally gzip-compressed. | Use for 1 vs 1 or 1 vs many runs. |
| `-r, --ref` | `null` | Single reference genome in FASTA/FASTQ format, optionally gzip-compressed. | Use for simple pairwise runs. |
| `--ql, --queryList` | `null` | Text file listing query genome paths, one genome per line. | Use for many-query runs. |
| `--rl, --refList` | `null` | Text file listing reference genome paths, one genome per line. | Use for many-reference runs or sketch creation. |
| `--sketch` | `null` | Load a previously written reference sketch prefix instead of rebuilding references. | Use for repeated querying against the same reference set. |

Gzip-compressed FASTA/FASTQ input is supported throughout the normal query and reference workflows.
For heavy benchmarking or repeated runs, uncompressed inputs may be faster because they avoid repeated gzip decompression.

Example command for creating a line-separated reference list:

```sh
find references/ -type f \( -name '*.fa' -o -name '*.fna' -o -name '*.fasta' -o -name '*.fa.gz' -o -name '*.fna.gz' -o -name '*.fasta.gz' \) | sort > references.txt
```

> If genome lists are copied or created from a Windows application, run `dos2unix` on the list file first to ensure the expected line-ending format.

### Output options

| Parameter | Default | Description | Typical use |
| --- | --- | --- | --- |
| `-o, --output` | `null` | Write the main tabular ANI results to this file. | Use for all runs. |
| `--write-ref-sketch` | `false` | Write a reference sketch database and exit. Requires `--ref` or `--refList`. | Use before repeated sketch-backed querying. |
| `--matrix` | `false` | Also write ANI values to `<output>.matrix` as a lower-triangular [PHYLIP-style matrix](https://www.mothur.org/wiki/Phylip-formatted_distance_matrix). | Use for all-vs-all matrix-style analyses. |
| `--visualize` | `false` | Also write fragment mappings to `<output>.visual` for each reported query/reference comparison. | Use when plotting conserved regions for selected genome pairs. |
| `--extended-metrics` | `false` | Report additional fragment-level ANI summary fields in the main tabular output only. | Use when you want more detailed fragment summary fields. |
| `--header` | `false` | Write a header row in the main tabular output only; it does not change `.matrix` or `.visual` sidecar files. | Use for easier downstream parsing. |

The main output is a tab-delimited file. Each row reports:

1. query genome
2. reference genome
3. ANI estimate
4. number of bidirectional fragment mappings
5. total query fragments
6. Frac99*
7. SdANI*
8. Q1*
9. Median*
10. Q3*

> * These fields are included only when `--extended-metrics` is enabled.

- Frac99*: fraction of mapped fragments with ANI at or above 99%
- SdANI*: standard deviation of fragment-level ANI values
- Q1*: first quartile of fragment-level ANI values
- Median*: median fragment-level ANI value
- Q3*: third quartile of fragment-level ANI values

Alignment fraction with respect to the query genome can be estimated as:

```text
bidirectional fragment mappings / total query fragments
```

> No ANI output is reported for genome pairs whose ANI is much lower than 80%. For those comparisons, amino-acid-level approaches such as [AAI](http://enve-omics.ce.gatech.edu/aai/) are more appropriate.

### Mapping parameters

Warning: non-default mapping parameters can change reported ANI values, hit counts, sensitivity, runtime, and sketch compatibility. Treat them as a different analysis configuration, not as harmless performance tweaks.

Most users should leave these at their defaults unless they have validated a different setup for their workload.

| Parameter | Default | Description | Typical use |
| --- | --- | --- | --- |
| `--window-size` | auto | Manually sets minimizer window size. Larger values usually reduce minimizer density and lower memory/runtime, but they can also change sensitivity and reported hits. In local benchmarking, `32` gave a noticeable runtime reduction with measurable result drift, while more aggressive values such as `36` and `48` drifted more. | Use only when you want direct control over sketching density and have validated the effect on your dataset. |
| `--reference-size` | `5000000` | Changes the assumption used by the automatic window-size calculation. The default is a rough estimate of average bacterial genome size. Larger values usually drive larger automatically chosen windows; smaller values usually do the opposite. If `--window-size` is set manually, this parameter no longer affects sketching. | Use when the default bacterial-genome assumption is a poor fit, such as for viruses or microbial eukaryotes, but you still want automatic window selection. |
| `--fragLen` | `3000` | Changes query fragmentation. | Use only after validating the sensitivity/runtime tradeoff for the dataset. |
| `-k, --kmer` | `16` | Changes the sketching unit. | Advanced tuning only; larger values can change sensitivity. |
| `--minFraction` | `0.2` | Changes which genome pairs are trusted and reported. | Use when you want stricter or looser shared-genome filtering. |
| `--maxRatioDiff` | `100.0` | Changes reference hash-density filtering during mapping. | Advanced debugging or workload-specific tuning. |

#### Warning: Mapping parameters will significantly change results

> Non-default mapping parameters can materially change reported ANI values, hit counts, and sketch compatibility.
>
> If you want to preserve the expected correlation to ANIb described in the original FastANI paper, do not change `--window-size`, `--reference-size`, `--fragLen`, or `-k/--kmer` without validating the effect on your dataset first. See [Jain et al. 2018](https://doi.org/10.1038/s41467-018-07641-9).

#### Estimating `--reference-size` from a reference list

```sh
# Reference list with one FASTA path per line.
ref_list=references.txt
n=$(wc -l < "$ref_list")

# Count non-header sequence characters across the full list.
total_bases=$(
  while IFS= read -r fasta; do
    gzip -cd "$fasta" 2>/dev/null || cat "$fasta"
  done < "$ref_list" |
    grep -v '^>' |
    tr -d '[:space:]' |
    wc -c
)

# Convert total bases into an average genome size.
avg_bases=$(
  awk -v total="$total_bases" -v n="$n" 'BEGIN {print int(total / n)}'
)

printf 'average_genome_size=%s\n' "$avg_bases"
```

This is only an example input to `--reference-size`, not a guarantee that the resulting automatic window size will preserve default behavior.
Using a smaller representative size is the more aggressive choice and can increase minimizer density; using a larger representative size is more conservative for memory/runtime but may reduce sensitivity.

### Execution options

| Parameter | Default | Description | Typical use |
| --- | --- | --- | --- |
| `-t, --threads` | `1` | Thread count for parallel execution. | Increase for faster runs on multicore systems. |
| `--batch-size` | all shards | Load sketch shards in batches during sketch-backed querying; requires `--sketch` and is incompatible with `--matrix` and `--write-ref-sketch`. A value of `1` gives the lowest peak memory usage, while omitting the option loads all shards at once. | Use when RAM is limited or when you want to tune the memory/runtime tradeoff. |
| `-s, --sanityCheck` | `false` | Run the built-in sanity check mode. | Use for debugging or internal validation. |
| `-h, --help` | `false` | Print the help page. | Use to inspect the CLI quickly. |
| `-v, --version` | `false` | Show the version. | Use when reporting or debugging installations. |

FastANI can persist reference sketches and reuse them across runs.

Build a sketch database:

```sh
fastANI --refList references.txt --write-ref-sketch reference_sketch
```

Reuse the sketch database:

```sh
fastANI --queryList queries.txt --sketch reference_sketch -o output.txt
```

This is especially useful when the same reference database is queried repeatedly.

#### Sketch-backed querying with RAM control

Load all sketch shards at once for the best sketch-backed runtime:

```sh
fastANI -q query.fa --sketch reference_sketch -o output.txt
```

Load one shard at a time for the lowest memory footprint:

```sh
fastANI -q query.fa --sketch reference_sketch --batch-size 1 -o output.txt
```

Use an intermediate batch size to trade RAM for better runtime:

```sh
fastANI -q query.fa --sketch reference_sketch --batch-size 5 -o output.txt
```

#### Batch-size memory heuristic

- As a rough rule of thumb, peak RAM is often close to `0.10 GiB + 2.8 x (sum of sketch shard sizes loaded together)`.
- For balanced sketches, you can approximate this as `0.10 GiB + 2.8 x batch_size x average_shard_size`.
- For a safer request on HPC or cloud systems, estimate from the largest shard instead of the average, then add another `20%` headroom for scheduler requests.

Example command for estimating query-time memory from an existing sketch prefix:

```sh
# Sketch prefix and desired shard batch size.
prefix=reference_sketch
batch=5

# Use the largest shard for a conservative estimate.
largest=$(stat -c '%s' "${prefix}".* | sort -nr | head -1)

# Convert bytes into a rough peak RAM estimate and a safer request.
awk -v bytes="$largest" -v batch="$batch" '
BEGIN {
  peak = 0.10 + 2.8 * batch * bytes / 1073741824
  req = 1.2 * peak

  printf("estimated_peak_rss=%.2f GiB\n", peak)
  printf("suggested_request=%.2f GiB\n", req)
}'
```

This uses the largest sketch shard as a conservative sizing input and reports a safer scheduler request.
Using the average shard size instead would be a more aggressive estimate and may underpredict memory on uneven datasets.

#### Sketch-build memory heuristic

- As a rough rule of thumb for default-style sketch creation, peak RAM often grows approximately linearly with total reference sequence content.
- A practical planning estimate is `peak_rss_gib ~= 0.5 + 7 x total_genome_gbp`.
- For a safer HPC or cloud request, round up to about `requested_ram_gib ~= 1 + 9 x total_genome_gbp`.
- This is only a heuristic: actual memory use depends on the dataset, repetitiveness, contig structure, and mapping parameters such as `--window-size`.

Example command for estimating sketch-build memory from a FASTA `--refList`:

```sh
# Text file containing one reference FASTA path per line.
ref_list=references.txt

# Count non-header sequence characters across all references.
bases=$(
  while read -r f; do
    gzip -cd "$f" 2>/dev/null || cat "$f"
  done < "$ref_list" |
  grep -v '^>' |
  tr -d '[:space:]' |
  wc -c
)

# Convert total bases into a conservative sketch-build request.
awk -v b="$bases" '
BEGIN {
  gbp = b / 1e9
  req = 1 + 9 * gbp

  printf("total_bases=%d (%.3f Gbp)\n", b, gbp)
  printf("suggested_request=%.2f GiB\n", req)
}'
```

This estimates total genomic content by removing FASTA header lines, stripping whitespace, and counting sequence characters, then converts that total into a conservative memory request.
This request formula is intentionally conservative; a more aggressive estimate would use the lower `0.5 + 7 x total_genome_gbp` rule of thumb instead.

### Output files

The main output is a tab-delimited file. Each row reports:

1. query genome: path or identifier for the query assembly
2. reference genome: path or identifier for the reference assembly
3. ANI estimate: estimated average nucleotide identity between the genome pair
4. number of bidirectional fragment mappings: reciprocal fragment matches supporting the ANI estimate
5. total query fragments: total number of query fragments considered for the comparison
6. `Frac99`*: fraction of mapped fragments with ANI at or above 99%
7. `SdANI`*: standard deviation of fragment-level ANI values
8. `Q1`*: first quartile of fragment-level ANI values
9. `Median`*: median fragment-level ANI value
10. `Q3`*: third quartile of fragment-level ANI values

\* These fields are included only when `--extended-metrics` is enabled.

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

No ANI output is reported for genome pairs whose ANI is much lower than 80%.
For those comparisons, amino-acid-level approaches such as [AAI](http://enve-omics.ce.gatech.edu/aai/) are more appropriate.

## Example run

Two small test genomes are available under [`tests/data`](tests/data).

```sh
fastANI \
  -q tests/data/Shigella_flexneri_2a_01.fna \
  -r tests/data/Escherichia_coli_str_K12_MG1655.fna \
  -o fastani.out
```

Example output:

```text
tests/data/Shigella_flexneri_2a_01.fna	tests/data/Escherichia_coli_str_K12_MG1655.fna	97.7507	1303	1608
```

This means the ANI estimate between the two genomes is `97.7507`, with `1303` reciprocal fragment mappings out of `1608` total query fragments.

## Visualization of conserved regions

FastANI can emit reciprocal mapping information for visualization in pairwise or multi-genome comparisons.

```sh
fastANI -q B_quintana.fna -r B_henselae.fna --visualize -o fastani.out
Rscript scripts/visualize.R B_quintana.fna B_henselae.fna fastani.out.visual
```

The generated `.visual` file can be plotted with the provided R script and [genoPlotR](https://cran.r-project.org/web/packages/genoPlotR/index.html). See also [issue #100](https://github.com/ParBLiSS/FastANI/issues/100).

For multi-genome runs, the `.visual` file may contain mappings for many genome pairs; in practice, the provided plotting workflow is most straightforward for one pair at a time.

<p align="center">
  <img
    src="docs/images/comparison.jpg"
    height="350"
    alt="Example FastANI conserved-region visualization"
  />
</p>

## Parallelization

FastANI supports multi-threading via `-t, --threads`.

For even larger workloads, users can also divide a large reference database into chunks and run multiple FastANI processes in parallel. The repository includes helper scripts for splitting databases for that purpose.

### Compatibility notes

Only options with limited interoperability are listed here. `✓` means the combination is supported. `X` means the combination is incompatible or not applicable.

| Option | `--ref` / `--refList` | `--sketch` | `--write-ref-sketch` | `--batch-size` | `--matrix` |
| --- | --- | --- | --- | --- | --- |
| `--ref` / `--refList` | ✓ | X | ✓ | X | ✓ |
| `--sketch` | X | ✓ | X | ✓ | ✓ |
| `--write-ref-sketch` | ✓ | X | ✓ | X | ✓ |
| `--batch-size` | X | ✓ | X | ✓ | X |
| `--matrix` | ✓ | ✓ | ✓ | X | ✓ |

Additional compatibility details:

- `--write-ref-sketch` requires reference input and does not use query input.
- `--header` and `--extended-metrics` affect only the main tabular output, not `.matrix` or `.visual` sidecar files.
- `--visualize` works for pairwise and multi-genome runs, but the bundled `scripts/visualize.R` example is pairwise-oriented.
- Sketches written with one `--window-size` are not interchangeable with runs using a different `--window-size`.
- Non-default `--reference-size` values can change the automatically chosen `--window-size`, so they can also change sketch compatibility and output behavior.
- More generally, sketches should be reused only when the mapping configuration is compatible with the configuration used when the sketch was written.

## Known behavior

### Asymmetry in ANI computation

FastANI can report slightly different ANI values for a genome pair `(A, B)` depending on which genome is used as the query and which is used as the reference. See [issue #36](https://github.com/ParBLiSS/FastANI/issues/36) for an example.

In practice, this difference is usually small. When `--matrix` output is requested, FastANI reports a single value per genome pair corresponding to the average of both directions.

## Quality guidance

Input quality matters. It is a good idea to quality-check both reference and query assemblies before running large analyses. As a practical rule of thumb, assemblies with N50 values below 10 Kbp may lead to weaker ANI estimates.

## Troubleshooting and support

Bug reports, feature requests, and general feedback are welcome through the [GitHub issue tracker](https://github.com/ParBLiSS/FastANI/issues).
