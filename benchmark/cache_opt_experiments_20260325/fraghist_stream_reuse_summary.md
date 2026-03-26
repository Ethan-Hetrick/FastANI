# Fragment Histogram Stream Reuse Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change kept:

- opened the per-split `--frag-hist` temp file once in the worker loop
- passed the live output stream into `computeCGI()` instead of reopening the same
  append file for every query/reference pair
- kept the histogram format and ANI output unchanged

Why this was worth trying:

- the histogram sidecar is written in the post-mapping CGI path
- the previous code paid a full open/close cycle for each pair even though each split
  writes to one temp file for its whole lifetime
- this is a localized I/O/overhead optimization that does not touch ANI logic

Validation:

- main ANI output matched exactly on a `20 x 20` no-sketch `--frag-hist` run
- `.hist` sidecar output matched exactly on the same run

Measured 20x20 `--frag-hist` run (`genome-list_20.txt`, `-t 2`):

- first ordering:
  - baseline summed post-mapping time: `0.507378 s`
  - experiment summed post-mapping time: `0.000787 s`
- reverse ordering:
  - experiment summed post-mapping time: `0.000809 s`
  - baseline summed post-mapping time: `0.608579 s`

Interpretation:

- this is a clear and repeatable win in the targeted post-mapping histogram path
- the benefit is exactly where expected: avoiding repeated file-open overhead
- the change is worth keeping whenever `--frag-hist` is enabled, especially for
  larger many-pair runs
