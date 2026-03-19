# FastANI

FastANI is a tool for fast, alignment-free computation of whole-genome Average Nucleotide Identity (ANI) between microbial genomes. It supports complete and draft assemblies, direct FASTA/FASTQ workflows, reusable reference sketches, and sketch batching for memory-constrained environments.

!!! note "Two documentation entry points"
This docs site is maintained separately from the GitHub-facing repository `README.md`.
The README stays optimized for repository browsing, while this homepage can use MkDocs features such as admonitions and richer navigation.

## Contents

### Jump to a section on this page

| Section                                         | What it covers                                  |
| ----------------------------------------------- | ----------------------------------------------- |
| [Start Here](#start-here)                       | The main entry points into the docs set         |
| [Installation](#installation)                   | Build and install guidance                      |
| [What FastANI Supports](#what-fastani-supports) | Core capabilities and important warnings        |
| [Common Workflows](#common-workflows)           | Canonical command examples                      |
| [Practical Notes](#practical-notes)             | Quick operational tips                          |
| [Related Docs](#related-docs)                   | Benchmark, changelog, and publication materials |

### Jump to another documentation page

| Page                                                  | Use it for                                          |
| ----------------------------------------------------- | --------------------------------------------------- |
| [Installation guide](install.md)                      | Building FastANI and verifying the CLI              |
| [Benchmark overview](benchmark/index.md)              | Benchmark scope, methods, and supporting files      |
| [Benchmark commands](benchmark/BENCHMARK_COMMANDS.md) | Reproducing benchmark runs directly                 |
| [Publication overview](pub/index.md)                  | Publication-facing figures and manuscript materials |
| [Publication draft](pub/pub_draft.md)                 | JOSS-style draft manuscript                         |
| [Fork changelog](CHANGELOG.md)                        | Technical change history since the fork             |
| [Reference material](references/index.md)             | Local papers and supporting references              |

## Start Here

- [Installation guide](install.md)
- [Benchmark docs](benchmark/index.md)
- [Publication docs](pub/index.md)
- [Reference material](references/index.md)

## Installation

See the dedicated [installation guide](install.md) for source builds and Release-mode recommendations.

## What FastANI Supports

- Pairwise ANI comparisons
- One-vs-many and many-vs-many genome comparisons
- Sketch-backed querying to avoid rebuilding references repeatedly
- Batch-controlled sketch loading with `--batch-size`
- Optional reciprocal averaging in sparse output with `--average-reciprocals`
- Optional tabular headers, matrix output, visualization output, and extended metrics

!!! warning "Mapping Parameters Change Results"
Non-default mapping parameters can materially change ANI values, hit counts, sensitivity, runtime, and sketch compatibility.

    If you want to preserve the expected correlation to ANIb described in the original FastANI paper, do not change `--window-size`, `--reference-size`, `--fragLen`, or `-k/--kmer` without validating the effect on your dataset first. See [Jain et al. 2018](https://doi.org/10.1038/s41467-018-07641-9).

!!! warning "Reproducibility matters"
For stable validated workflows, keep mapping parameters fixed, save the reference list and sketch artifacts together, and make saved sketches read-only after creation.

    Use `--average-reciprocals` consistently if you want one sparse row per reciprocal genome pair. In that mode, `ANI` and the `FragID_*` fields are averaged across reciprocal rows, while count and alignment-fraction columns remain tied to the displayed row. Prefer `--batch-size` over mapping-parameter changes when the goal is only to reduce RAM usage.

## Common Workflows

Pairwise comparison:

```sh
fastANI -q QUERY_GENOME -r REFERENCE_GENOME -o output.txt
```

One query against many references:

```sh
fastANI -q QUERY_GENOME --refList references.txt -o output.txt
```

Build and reuse a sketch:

```sh
fastANI --refList references.txt --write-ref-sketch reference_sketch
fastANI -q QUERY_GENOME --sketch reference_sketch -o output.txt
```

Symmetrize reciprocal rows in sparse output:

```sh
fastANI --queryList queries.txt --refList references.txt --average-reciprocals --header -o output.txt
```

Low-memory sketch-backed querying:

```sh
fastANI -q QUERY_GENOME --sketch reference_sketch --batch-size 1 -o output.txt
```

## Practical Notes

!!! tip "Compressed input is supported"
Gzip-compressed FASTA/FASTQ input is supported for normal query and reference workflows.
For heavy benchmarking or repeated runs, uncompressed inputs may be faster because they avoid repeated gzip decompression.

!!! tip "Creating reference lists"
Example command for creating a line-separated reference list:

    ```sh
    find references/ -type f \( -name '*.fa' -o -name '*.fna' -o -name '*.fasta' -o -name '*.fa.gz' -o -name '*.fna.gz' -o -name '*.fasta.gz' \) | sort > references.txt
    ```

!!! warning "Windows-created list files"
If genome lists are copied or created from a Windows application, run `dos2unix` on the list file first to ensure the expected line-ending format.

## Related Docs

- [Benchmark overview](benchmark/index.md)
- [Benchmark commands](benchmark/BENCHMARK_COMMANDS.md)
- [Fork changelog](CHANGELOG.md)
- [Publication draft](pub/pub_draft.md)
