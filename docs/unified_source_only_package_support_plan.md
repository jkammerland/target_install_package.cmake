# Unified Source-Only Package Support Plan

## Planning Context

The saved story in [unified_source_only_package_support_story.md](unified_source_only_package_support_story.md) reflects an older design point from PR #49.

The current branch already changed the implementation materially:

- `SOURCE_FILES` is gone from the public API.
- `target_install_package()` now uses `INCLUDE_SOURCES NO|EXCLUSIVE`.
- Included-source payload is extracted automatically from target metadata (`SOURCES`, `HEADER_SETS`, `CXX_MODULE_SETS`) instead of a second file list.
- `INCLUDE_SOURCES EXCLUSIVE` generates a local consumer target during `find_package()` rather than exporting an imported target with relocated `INTERFACE_SOURCES`.
- The SDK example is now named `sdk`, not `sdk-hybrid`.
- The old module helper files were removed.

Any follow-up work should build on that branch state, not reintroduce the older `SOURCE_FILES` and imported-`INTERFACE_SOURCES` model.

## Current-State Reading Of The Story

The story is still directionally useful, but these parts are stale and should not be implemented literally:

- `SOURCE_FILES` / `SOURCE_DESTINATION` as the primary API
- source-only support being restricted to `INTERFACE` targets
- the installed imported target being the authoritative source-backed target
- the old module-helper repair flow for imported targets
- the `sdk-hybrid` naming

The current implementation already chose a different and cleaner architecture:

- keep one entry point
- make source inclusion automatic
- use explicit `NO` vs `EXCLUSIVE`
- let consumers select the generated local target kind via `<alias>_LIBRARY_TYPE`
- allow dual install by invoking `target_install_package()` twice with different aliases

## Implementation Goal

Finish the feature as a coherent, documented, and conservative package shape:

- binary/imported packages stay `INCLUDE_SOURCES NO`
- source-backed packages use `INCLUDE_SOURCES EXCLUSIVE`
- mixed SDKs combine both explicitly in the same export
- modules remain a separate compatibility tier
- CPS stays follow-up work and must not distort the CMake-native model

## Proposed Work Items

### 1. Consolidate the public story around the shipped API

Update the docs so the official narrative matches the code that exists now.

Scope:

- keep [included_sources_user_story.md](included_sources_user_story.md) as the primary user-facing story for the implemented model
- treat the newly saved story as historical planning input, not current product docs
- make sure `README.md`, `docs/default_install_dirs.md`, `examples/README.md`, and example READMEs consistently describe:
  - `INCLUDE_SOURCES NO|EXCLUSIVE`
  - automatic extraction from target metadata
  - local target regeneration for `EXCLUSIVE`
  - dual-install for mixed SDKs
  - `<alias>_LIBRARY_TYPE`

Success criteria:

- no public docs tell users to maintain a second package-only source list
- no docs imply imported `INTERFACE_SOURCES` are still the main implementation model

### 2. Harden extraction and diagnostics

The main implementation is in place, but the next pass should tighten failure modes and migration guidance.

Scope:

- review `target_install_package.cmake` extraction rules for:
  - generator expressions in `SOURCES`
  - generated files
  - duplicate file-set/source overlap
  - missing public file sets for headers/modules
  - unsupported target graphs that mix imported and exclusive-only siblings
- improve diagnostics so errors explain both the problem and the expected fix
- add a migration note for anyone coming from the removed `SOURCE_FILES` API

Likely files:

- [target_install_package.cmake](../target_install_package.cmake)
- [README.md](../README.md)
- [docs/default_install_dirs.md](default_install_dirs.md)

### 3. Expand regression coverage around the chosen model

The current branch already has meaningful coverage. The next test pass should target the edges of the new semantics.

Add or tighten tests for:

- dual install of the same producer target as `NO` and `EXCLUSIVE`
- invalid `<alias>_LIBRARY_TYPE` values
- interface-only `EXCLUSIVE` targets, if they are intended to remain supported
- unsupported source extraction cases producing stable diagnostics
- module package coverage remaining generator/toolchain-gated

Likely files:

- [tests/cmake/run_source_package_test.cmake](../tests/cmake/run_source_package_test.cmake)
- [tests/cmake/run_source_package_export_test.cmake](../tests/cmake/run_source_package_export_test.cmake)
- [tests/cmake/run_source_package_modules_test.cmake](../tests/cmake/run_source_package_modules_test.cmake)
- [tests/source-package/CMakeLists.txt](../tests/source-package/CMakeLists.txt)
- [tests/source-package-export/CMakeLists.txt](../tests/source-package-export/CMakeLists.txt)
- [tests/source-package-modules/CMakeLists.txt](../tests/source-package-modules/CMakeLists.txt)

### 4. Keep modules explicitly experimental

The current implementation is better than the old imported-target helper flow, but the module tier still needs conservative messaging.

Current official CMake docs still say:

- `find_package()` can import CPS packages in CMake 4.3
- `install(PACKAGE_INFO)` / `export(PACKAGE_INFO)` are the preferred CPS generation path
- compiling BMIs from `IMPORTED` targets with C++ modules is not supported

That means:

- the current generated-local-target model is the right baseline for source-backed modules
- module examples and tests should remain conditional
- docs should avoid promising cross-generator portability that CMake itself does not provide

### 5. Treat CPS as a follow-up layer, not part of the current milestone

This is the main future-looking item in the saved story.

Recommended approach:

- do not block the current included-source model on CPS work
- when CPS work starts, gate it on CMake 4.3+
- use `install(PACKAGE_INFO)` / `export(PACKAGE_INFO)` directly rather than `CMAKE_INSTALL_EXPORTS_AS_PACKAGE_INFO`
- install `.cps` files into actual CPS search locations
- skip or sharply constrain CPS generation for `INCLUDE_SOURCES EXCLUSIVE` packages until the mapping is honest

Working rule:

- imported binary/header-only shapes may map cleanly
- source-backed `EXCLUSIVE` targets should continue to rely on `Config.cmake` as the authoritative mechanism unless a faithful CPS model is proven

## Recommended Sequence

1. Save the historical story and current-state plan.
2. Do a documentation alignment pass so the public story matches the branch behavior.
3. Harden diagnostics and edge-case tests around extraction, dual install, and local target generation.
4. Keep module support conditional and clearly documented as a compatibility tier.
5. Start CPS as a separate, version-gated follow-up once the CMake-native model is fully settled.

## Non-Goals

This plan does not recommend:

- restoring `SOURCE_FILES`
- switching back to imported `INTERFACE_SOURCES` as the primary implementation
- adding a second top-level packaging API
- forcing CPS generation for package shapes that do not map cleanly

## Suggested First Implementation Slice

If the next change should stay reviewable, the best slice is:

1. documentation alignment
2. migration note for the removed `SOURCE_FILES` concept
3. a small test expansion for dual-install and invalid library type handling

That slice is small enough for one PR and directly reduces confusion created by the story drift between PR #49 and the branch state now.
