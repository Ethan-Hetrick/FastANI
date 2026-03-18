---
title: "FastANI: sketch reuse and batched sketch loading for scalable average nucleotide identity workflows"
tags:
  - average nucleotide identity
  - comparative genomics
  - microbial genomics
  - sketching
  - high-performance computing
authors:
  - name: "TODO: Author Name"
    affiliation: "1"
    corresponding: true
affiliations:
  - name: "TODO: Affiliation, Country"
    index: 1
date: "18 March 2026"
bibliography: paper.bib
---

# Summary

FastANI is a widely used tool for computing whole-genome average nucleotide identity (ANI) among microbial genomes. ANI is commonly used for species delineation, reference matching, and large-scale genome screening. The original FastANI work introduced an alignment-free approximate mapping strategy that was shown to remain accurate for both finished and draft genomes while substantially reducing runtime relative to alignment-based ANI workflows. In practice, however, repeated comparison against stable reference collections can still be limited by reference preprocessing costs and high memory requirements during sketch-backed querying. This fork extends FastANI with reusable reference sketches, explicit sketch-batch controls, richer output options, and a set of performance improvements aimed at large-scale production use.

The resulting workflow better separates one-time reference preparation from repeated query execution. A reference collection can be sketched once, stored, and reused across many queries. Query-side memory use can then be controlled with a `--batch-size` parameter that trades runtime for lower peak memory by loading only a subset of sketch shards at a time. These changes are accompanied by implementation-level optimizations in both query mapping and reference preprocessing, along with expanded documentation and benchmarking materials to support reproducible deployment.

# Statement of need

FastANI is frequently used in settings where many genomes must be screened against a relatively stable reference database. These include public health pipelines, microbial surveillance, reference curation, and workflow-managed analyses on shared clusters or cloud platforms. In these settings, repeated rebuilding of the reference-side data structures is costly, and large in-memory reference representations can constrain concurrency and increase the chance of failed jobs.

The original FastANI paper already separated one-time reference indexing from the compute phase and noted that memory pressure on very large databases could be reduced by distributing work across nodes or by processing chunks of the reference database one by one. This fork addresses that operational need directly inside the tool. Instead of leaving reference reuse and chunk management as an external workflow concern, it adds persistent sketch databases, lower-memory sketch-backed querying, and user-controlled batch sizing as first-class execution modes.

This fork was developed to address those operational limitations without changing the core role of FastANI as a high-throughput ANI engine. The target users are researchers and infrastructure engineers who need to run FastANI repeatedly, reproducibly, and at larger scale than is comfortable with a rebuild-per-query workflow. The main goals were:

- reduce repeated reference-side work by persisting reference sketches;
- lower the memory barrier for sketch-backed querying;
- expose a practical memory/runtime tradeoff through batched sketch loading;
- improve documentation around parameter compatibility and mapping tradeoffs; and
- preserve result fidelity while improving operational performance.

These changes are intended to make FastANI easier to integrate into workflow systems where many independent jobs are scheduled concurrently and where predictable resource requests matter.

# State of the field

FastANI already occupies an important niche among ANI and genome similarity tools because it provides an established, alignment-free approximation strategy with a simple command-line interface and broad adoption in microbial genomics. The goal of this work is therefore not to replace FastANI with a new ANI method, but to improve the scalability and operational behavior of the existing software.

Within that scope, the most relevant comparison is therefore not to a different biological method, but to the baseline FastANI implementation described in the original publication. The scholarly contribution of this fork is an engineering and usability advance built on that method: it expands the execution model of FastANI for repeated-query and infrastructure-oriented use cases while preserving compatibility with established ANI practice. This includes stronger sketch-centric workflows, lower-memory query execution, clearer parameter guidance, and documented resource-planning heuristics.

This “extend rather than replace” approach is also justified by current user expectations. Downstream pipelines, benchmark baselines, and operational deployments are often tied to FastANI specifically. Improving its scalability and reliability therefore has direct value even when the underlying ANI formulation remains unchanged.

# Software design

The design centers on separating one-time work from repeated work. Reference-side preprocessing is captured in reusable sketch files, allowing the reference representation to be built once and loaded many times. On the query side, the execution model is extended so that sketch shards can be loaded either all at once or in configurable batches. This produces a continuum between maximum throughput and minimum memory use, rather than forcing a single memory-saving mode.

The fork also includes a series of implementation-level performance changes that do not alter the intended algorithmic output. These include reduced allocation churn, reuse of temporary buffers in hot paths, less copying during L1/L2 mapping, reduced synchronization overhead in postprocessing, and targeted improvements in minimizer-generation and sketch-loading paths. During development, candidate optimizations that introduced regressions were explicitly backed out or revised, and benchmarking was used as the primary acceptance criterion for performance-oriented changes.

The current sketch query model supports three practically useful operating points:

- load all sketch shards at once for maximum sketch-backed performance;
- use `--batch-size 5` to recover much of that performance while lowering memory;
- use `--batch-size 1` to minimize per-job memory at the cost of additional batching overhead.

This design is especially useful on HPC and cloud platforms. Instead of assigning a large memory allocation to every ANI job, users can choose a batch size that fits their scheduler and concurrency model. In that sense, the fork operationalizes and formalizes a strategy that the original FastANI paper discussed conceptually for large databases: processing only part of the reference database at a time to reduce peak memory. The repository also now includes explicit memory-planning heuristics for sketch creation and sketch-backed querying so that users can estimate requests from reference content or sketch shard sizes.

Performance evaluation in this fork was conducted with repository-local benchmarking scripts and repeated Release-mode runs. The maintained benchmark suite uses `tests/data/Shigella_flexneri_2a_01.fna` as a fixed query genome and a randomly sampled half-list of 5032 references derived from `genome-list.txt`. For each benchmark configuration, the repository executes three repeated runs and records `/usr/bin/time -v` outputs together with FastANI's internal timing logs. The benchmark table captures wall time, reference-build or sketch-load time, query-mapping time, post-mapping time, CPU utilization, filesystem I/O, and peak resident set size. The evaluated configurations include the original FastANI baseline, the current no-sketch execution path, all-shards sketch loading, and batched sketch execution with `--batch-size 5` and `--batch-size 1` using an eight-shard reference sketch. Exact-output validation is performed with file-level `diff` checks between comparable modes, and the resulting CSV tables, validation logs, plotting scripts, and dashboard figures are bundled under `docs/pub` so that the performance claims in this manuscript are directly auditable.

# Research impact statement

The impact claim for this fork is based on reproducible benchmarking materials included in the repository. On a maintained half-list benchmark using Release-mode builds, the current no-sketch execution path is about 9.9% faster than the original tool overall, with the largest improvement in query mapping. More substantially, prebuilt sketch use changes the cost structure of repeated querying: loading a prebuilt sketch is about 20.4x faster than rebuilding the reference-side data structures in the benchmarked configuration.

The most consequential operational change is the addition of batched sketch loading. In the current benchmark set, all sketch-backed execution modes preserved exact output agreement against the standard sketch query baseline across repeated runs. Relative to the original tool on the maintained benchmark workload:

- loading all sketch shards at once reduced end-to-end runtime by about 12.6x;
- `--batch-size 5` reduced runtime by about 88.6% while lowering peak RSS by about 26.2%;
- `--batch-size 1` reduced runtime by about 64.6% while lowering peak RSS by about 82.9%.

These results are important because they show that the fork improves not only raw runtime, but also the deployability of FastANI in resource-constrained and highly parallel environments. The repository now includes a benchmark runner, raw benchmark tables, validation outputs, and a publication-style dashboard under `docs/pub`, making the performance claims inspectable and reproducible by reviewers.

The likely near-term impact is therefore practical rather than methodological: this work makes FastANI easier to run repeatedly, easier to schedule at scale, and less likely to fail due to avoidable memory pressure in shared compute environments.

![Release-mode benchmark dashboard comparing the original FastANI baseline, the current no-sketch execution path, and three sketch-backed execution modes (all shards, `--batch-size 5`, and `--batch-size 1`). The figure summarizes runtime composition, peak memory, and relative performance changes derived from the reproducible benchmark materials bundled with this repository.\label{fig:performance-dashboard}](images/publication_performance_dashboard.png)

# AI usage disclosure

Generative AI tools were used during development of this fork for coding assistance, documentation drafting, benchmark-analysis support, and manuscript editing. In particular, the GPT-5.4 code agent was used for the bulk of the initial implementation work across performance-oriented C++ changes, sketch-query execution changes, benchmark runner development, dashboard generation, changelog preparation, and early manuscript drafting. All AI-assisted code and text were subsequently reviewed by the project authors in the repository. For software changes, retained contributions were required to compile locally, pass functional checks, preserve expected output where applicable, and survive benchmark-based review before they were kept. For documentation and manuscript text, AI-generated material was treated as draft language and revised against repository-local evidence, including benchmark tables, validation logs, and source code inspection.

# Acknowledgements

This draft should be updated with project-specific funding, institutional support, and contributor acknowledgements before submission. If the software is archived for submission, the archived release DOI should also be incorporated into the final manuscript metadata.

# References

This draft still needs a final `paper.bib` file and complete in-text citations before JOSS submission. At minimum, the final references should include:

- the original FastANI publication by Jain et al. (2018);
- the original FastANI software repository or release reference, as appropriate;
- any directly relevant ANI or genome-similarity software used for context in the state-of-the-field section; and
- any workflow or deployment references that are discussed explicitly in the final manuscript.
