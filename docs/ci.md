# CI overview (workflows → scripts)

This repository’s GitHub Actions workflows are intentionally thin wrappers around `ci/run.sh` so that the same checks can be executed locally (with identical arguments and outputs).

## DAG (high-level)

```mermaid
graph TD
  CI[.github/workflows/ci.yml] --> B[build (matrix)]
  CI --> FL[CMake feature floors and latest]
  CI --> WCL[Windows Ninja + clang-cl modules]
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
  CPK --> CPK5[self-release package]
  CPK --> CPK6[checksum compatibility]
  CPK --> CPK7[SBOM API compatibility]

  REL[.github/workflows/release.yml] --> RELV[verify signed tag without secrets]
  RELV -->|release environment approval| REL1[signed self-release package]
  REL1 --> REL2[immutable GitHub release]
```

## Workflow → script mapping

- `ci.yml`
  - `cmake-feature-lanes`: exact CMake `3.25.0`, `3.28.4`, and `4.4.2` core, module, and latest-feature proofs
  - `windows-clang-cl-modules`: CMake `4.4.2` with Ninja and `clang-cl`
  - `build`: `ci/run.sh bootstrap` → `ci/run.sh main` → `ci/run.sh consumer`
  - `test-integration`: `ci/run.sh consumer --suite integration`
  - `test-examples`: `ci/run.sh examples --suite {single|multi} --use-fetchcontent`
  - `*-consume`: `ci/run.sh examples --suite consume-*`
- `packaging-tests.yml`: `ci/run.sh bootstrap --packaging-tools` → `ci/run.sh packaging-tests`
- `cpack.yml`: package integration plus exact CMake `3.25.0` fallback checksums, `4.2.3` native checksums, and `4.3.4`/`4.4.2` SBOM syntax proofs
- `release.yml`: when dispatched from the default branch, verifies an existing annotated tag with the pinned public key and confirms that its commit belongs to `master`; after release-environment approval, imports the private key, runs `ci/run.sh cpack --suite self-release --require-signing`, and publishes the signed archives, SPDX SBOM, signatures, checksums, and public verification key

## Local parity (common entrypoints)

- Bootstrap dependencies: `bash ci/run.sh bootstrap --ninja --fmt`
- Configure/build/test/install root project: `bash ci/run.sh main --preset ci-release`
- Consumer tests: `bash ci/run.sh consumer --preset ci-release`
- Examples: `bash ci/run.sh examples --suite single --build-type Release --use-fetchcontent`
- Packaging: `bash ci/run.sh packaging-tests`
- CPack: `bash ci/run.sh cpack --suite regression`
- Latest-feature preset: `cmake -S . --presets-file cmake/presets/CMakePresets-4.4.json --preset ci-modern -Werror=install-absolute-destination`
- Self-release package dry run: `bash ci/run.sh bootstrap --cmake-version 4.4.2 --ninja --gpg && bash ci/run.sh cpack --suite self-release`
- Release tag verification: `bash ci/run.sh release verify-tag --tag v7.1.0 --trusted-ref refs/remotes/origin/master`

## Tagged releases

Release assets are signed with the dedicated GPG key whose full fingerprint is `7A9DA5E43CC1A9ECB9745CBE3A209DA2768BE08D`. Its public key is checked in at `.github/release-signing-key.asc`. The `GPG_PRIVATE_KEY`, optional `GPG_SIGNING_KEY`, and optional `GPG_PASSPHRASE` values must be environment secrets on the protected `release` environment, not repository-level secrets.

Release tags must be annotated, signed by that exact key, match the version in `CMakeLists.txt`, and point to a commit contained in `master`. The secret-free verification job enforces those conditions before the private-key job can start. The release job then checks that the tag still resolves to the verified commit before building.

Configure the repository with an active tag ruleset matching `v*` that restricts tag creation, updates, and deletion to administrators. Configure the `release` environment with a required reviewer and allow only the selected `master` branch, because the trusted workflow is dispatched from `master` and verifies the tag input separately. Move the GPG secrets into that environment and remove their repository-level copies. Enable immutable releases before publishing the next version.

To publish a release:

1. Merge the version bump and wait for all required checks on `master`.
2. Create and push a signed annotated tag from that exact `master` commit.
3. Run the `Tagged Release` workflow from `master` with the tag name as its input.
4. Review and approve the `release` environment deployment.

Do not create or publish the release through the GitHub Releases page. The workflow creates a draft, uploads and verifies every asset, then publishes it. It refuses to replace assets on an existing published release.

Publishing makes the release, assets, and tag immutable. If an erroneous immutable release is deleted, GitHub permanently reserves its tag name; advance to a new version instead of trying to recreate that tag. Version `v7.0.7` is retired and must not be reused.

## Logging and outputs

- Scripts run CMake with `--log-level=DEBUG` and enable project log colors via `-DPROJECT_LOG_COLORS=ON`.
- CI outputs are written under `build/` (for example `build/ci/*`, `build/ci-consumer/*`, `build/examples/*`, `build/packaging/*`, `build/cpack/*`) to avoid polluting the source tree.
