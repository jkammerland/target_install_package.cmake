# CI overview (workflows → scripts)

This repository’s GitHub Actions workflows are intentionally thin wrappers around `ci/run.sh` so that the same checks can be executed locally (with identical arguments and outputs).

## DAG (high-level)

```mermaid
graph TD
  CI[.github/workflows/ci.yml] --> B[build (matrix)]
  B -->|needs| INT[test-integration]
  CI --> EX[test-examples (matrix)]
  CI --> CSM[multi-config-consume (matrix)]
  CI --> CSS[single-config-consume (matrix)]
  CI --> CFHS[fhs-combined-consume (matrix)]

  PKG[.github/workflows/packaging-tests.yml] --> PKG1[build/test packages]
  PKG --> PKG2[multi-arch detection]

  CPK[.github/workflows/cpack.yml] --> CPK1[cpack basic (matrix)]
  CPK --> CPK2[cpack regression]
  CPK --> CPK3[cpack components]
  CPK --> CPK4[cross-platform validation]
```

## Workflow → script mapping

- `ci.yml`
  - `build`: `ci/run.sh bootstrap` → `ci/run.sh main` → `ci/run.sh consumer`
  - `test-integration`: `ci/run.sh consumer --suite integration`
  - `test-examples`: `ci/run.sh examples --suite {single|multi} --use-fetchcontent`
  - `*-consume`: `ci/run.sh examples --suite consume-*`
- `packaging-tests.yml`: `ci/run.sh bootstrap --packaging-tools` → `ci/run.sh packaging-tests`
- `cpack.yml`: `ci/run.sh bootstrap --packaging-tools --gpg` → `ci/run.sh cpack ...`

## Local parity (common entrypoints)

- Bootstrap dependencies: `bash ci/run.sh bootstrap --ninja --fmt`
- Configure/build/test/install root project: `bash ci/run.sh main --preset ci-release`
- Consumer tests: `bash ci/run.sh consumer --preset ci-release`
- Examples: `bash ci/run.sh examples --suite single --build-type Release --use-fetchcontent`
- Packaging: `bash ci/run.sh packaging-tests`
- CPack: `bash ci/run.sh cpack --suite regression`

## Logging and outputs

- Scripts run CMake with `--log-level=DEBUG` and enable project log colors via `-DPROJECT_LOG_COLORS=ON`.
- CI outputs are written under `build/` (for example `build/ci/*`, `build/ci-consumer/*`, `build/examples/*`, `build/packaging/*`, `build/cpack/*`) to avoid polluting the source tree.
