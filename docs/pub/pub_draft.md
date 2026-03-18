# Publication draft

## Purpose

This work aims to improve FastANI along four practical dimensions: utility, accessibility, scalability, and performance. The motivation is practical as much as technical: in real use, runtimes were often abysmal, and memory-related crashes were frequent enough to become a recurring source of frustration. These limitations made the tool harder to use in production-style workflows, especially when scaling to many samples or large reference collections.

A major theme is reducing repeated overhead. By enabling reusable reference sketches, FastANI can avoid rebuilding the full reference database for every query. This makes the workflow more efficient on personal workstations, shared HPC systems, and cloud-based orchestration frameworks such as Nextflow. In parallel, we improve user-facing documentation and parameter guidance so that advanced options are easier to understand and use correctly.

We also introduce a reduced-memory query mode aimed at large-scale, embarrassingly parallel use cases. In prior workflows, each query job effectively paid the cost of loading the full reference database into memory, which limited how easily FastANI could be scaled across many simultaneous jobs. With reusable sketches and lower-memory querying, large batches of samples can be distributed as many single-CPU tasks across HPC or cloud environments while keeping per-task memory demands substantially more manageable.

## Impact

These improvements can support more timely public health and microbial genomics workflows, including rapid species identification and genome similarity screening using ANI. Reducing repeated database construction lowers compute cost and improves throughput in production settings, especially when many queries are run against a stable reference set. Just as importantly, lowering memory pressure reduces the likelihood of failed runs and makes the tool less painful to operate in practice.

Reusable sketches also improve reproducibility by making it easier to preserve and reuse the exact reference representation used for a given analysis. This is especially valuable in regulated or audit-sensitive settings, including environments where consistent reruns and report traceability matter. More broadly, better documentation and clearer parameter guidance reduce the barrier to adoption and help users make informed tradeoffs between runtime, memory use, and result fidelity.

From an infrastructure perspective, the combination of sketch reuse and reduced-memory querying helps shift FastANI from a workstation-oriented pattern toward a more scalable execution model. Instead of allocating large memory footprints to every query task, users can schedule many independent single-core jobs with more predictable resource requirements. That makes the approach a better fit for future large-scale surveillance, cloud-native analysis, and workflow-managed deployments.
