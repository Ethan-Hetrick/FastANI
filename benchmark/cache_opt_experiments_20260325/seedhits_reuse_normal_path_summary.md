# Normal-Path Seed-Hit Reuse Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change attempted:

- threaded a reusable `seedHitsL1` vector through the normal no-sketch
  `mapSingleQuerySeq()` / `doL1Mapping()` path
- mirrored the reuse strategy already used in the prepared cached-query path

Why this was worth trying:

- the normal path still allocates a fresh seed-hit vector for every query fragment
- the prepared path already proved that this buffer can be reused safely
- this looked like a plausible small allocation/cache cleanup for repeated fragment mapping

Validation:

- output matched exactly on a small no-sketch Kalamari workload
- no correctness issues were observed

Measured spot checks:

- tiny 6-reference run, 3 repeats:
  - baseline mean reference phase: `0.207884 s`
  - experiment mean reference phase: `0.203188 s`
  - baseline mean query phase: `0.302286 s`
  - experiment mean query phase: `0.306296 s`
  - baseline mean max RSS: `59,057 kB`
  - experiment mean max RSS: `57,620 kB`
- 20-reference warm-cache spot check:
  - outputs matched exactly
  - internal FastANI phase timers moved in the expected direction
  - outer wall-clock timing was noisy enough to be untrustworthy for a keep/discard decision

Decision:

- not kept

Interpretation:

- the change appears functionally safe
- it may trim a little transient memory
- the runtime signal was too weak and noisy to justify carrying another hot-path API
  change in the normal mapping path
- this is not a strong enough win to keep without a cleaner benchmark showing a
  consistent advantage
