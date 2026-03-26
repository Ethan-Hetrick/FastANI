# CGI Genome-Length Cache Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change attempted:

- precomputed query and reference genome lengths by id before writing ANI rows in
  `outputCGI()`
- avoided repeated unordered-map lookups by genome name on each output row

Why this was worth trying:

- `outputCGI()` still performed two string-keyed map lookups for every reported ANI row
- this looked like a plausible micro-optimization for output-heavy runs

Validation:

- main ANI output matched exactly on a `20 x 20` no-sketch run
- no correctness issues were observed

Measured 20x20 no-sketch run (`genome-list_20.txt`, `-t 2`):

- baseline summed post-mapping time: `0.000214 s`
- experiment summed post-mapping time: `0.000230 s`

Decision:

- not kept

Interpretation:

- this workload did not show a real benefit from precomputing per-id length vectors
- the measured output-path time was already extremely small, and the attempted cache
  was slightly slower rather than faster
