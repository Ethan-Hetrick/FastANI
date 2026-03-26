# CGI Output Copy-Elision Experiment

Date: `2026-03-25`

Branch: `perf/cache-optimization`

Change attempted:

- move-merged per-thread CGI result vectors into the final merged result vector
- avoided copying the full CGI result vector in `outputCGI()` when reciprocal
  averaging was disabled, sorting the working vector directly instead

Why this was worth trying:

- this looked like a clean way to trim avoidable result-copy overhead late in the
  CGI/output path
- larger output-heavy runs are one of the few places where these copies could still
  matter

Validation:

- main ANI output matched exactly on a `20 x 20` no-sketch run
- no correctness issues were observed

Measured 20x20 no-sketch run (`genome-list_20.txt`, `-t 2`):

- baseline summed post-mapping time: `0.000259 s`
- experiment summed post-mapping time: `0.000245 s`

Decision:

- not kept

Interpretation:

- the output path is already cheap enough on this workload that copy elision here
  does not create a meaningful end-to-end win
- the measured difference was too small to justify additional code complexity or to
  claim a reliable improvement
