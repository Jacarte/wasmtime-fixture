# Wasmtime safe-v1 evaluator task repository

Private evaluator-only task data for the `pepi/upstream-safe-v1` dataset. Keep this repository separate from the public Pepi source repository and never mount it into agent containers or include it in task image layers. The CI workflow checks out this repository at a pinned commit on the host; task images fetch only the exact upstream Wasmtime base commits.

The ordered task IDs are in `ids.txt`; SWE-bench metadata and evaluator files are under `tasks/`. Update the main Pepi preset/task revision together when changing this repository.
