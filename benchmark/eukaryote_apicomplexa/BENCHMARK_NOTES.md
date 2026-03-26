# Apicomplexa Benchmark Notes

This directory is being used for a simple eukaryote benchmark using
Apicomplexa assemblies downloaded with NCBI `datasets`.

Repo-owned helper scripts:

- `prepare_apicomplexa_inputs.sh`
- `run_old_vs_new_20v_all.sh`
- `run_old_vs_new_1v_all.sh`

Intended uses:

- prepare the downloaded dataset into query/reference lists
- compare legacy FastANI against the current build on Apicomplexa genomes

Current lightweight probe:

- `1` query genome vs `20` Apicomplexa references
- both old and current runs completed successfully

Heavier run design:

- `1` query genome vs all available references
- or `20` queries vs all available references

The downloaded archive and generated benchmark outputs in this directory are
local benchmark artifacts and should be treated separately from the helper
scripts.
