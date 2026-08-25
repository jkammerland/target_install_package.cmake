# Multiple-Component Installs

CMake 4.4 extends the native [`cmake --install --component`](https://cmake.org/cmake/help/v4.4/manual/cmake.1.html#cmdoption-cmake-install-component) interface to accept more than one component. `target_install_package()` already emits normal CMake component rules, so no project-specific install wrapper is needed.

## Direct Installs

Pass all selected components after one option:

```bash
cmake --install build \
  --component Runtime Development \
  --prefix "$PWD/stage"
```

Repeating the option is equivalent:

```bash
cmake --install build \
  --component Runtime \
  --component Development \
  --prefix "$PWD/stage"
```

The custom prefix applies to every selected component in that invocation. CMake 3.25 through 4.3 still support the same generated install rules, but require one component per invocation:

```bash
cmake --install build --component Runtime --prefix "$PWD/stage"
cmake --install build --component Development --prefix "$PWD/stage"
```

The existing single-component and full-install paths are unchanged:

```bash
# One payload slice.
cmake --install build --component Runtime

# Every non-EXCLUDE_FROM_ALL install rule, including unrelated components.
cmake --install build
```

## Exit Status Warning For CMake 4.4

**Do not use one multi-component invocation as a fail-safe status gate with released CMake 4.4.0 through 4.4.2.** In serial mode, an earlier component script that calls `cmake_language(EXIT <nonzero>)` can be masked by a later successful component. With CMake's `INSTALL_PARALLEL` mode, any child install failure can be masked and the command can still exit successfully.

This is upstream [CMake issue 27906](https://gitlab.kitware.com/cmake/cmake/-/issues/27906). It is fixed on CMake's development branch by [commit `ae5f5069`](https://gitlab.kitware.com/cmake/cmake/-/commit/ae5f5069061b1ddfd5f0609fd99204ef5be4fb77), but no fixed release is available yet. Until using a release that contains that fix, status-sensitive automation should run one component per serial invocation and stop after the first nonzero result:

```bash
cmake --install build --component Runtime --prefix "$PWD/stage" &&
  cmake --install build --component Development --prefix "$PWD/stage"
```

The one-invocation form remains useful for successful installs, but affected CMake versions do not reliably aggregate component failure statuses.

## Selection Semantics

- Component names are selections, not a dependency request. A `Development` component that depends on `Runtime` in CPack metadata still installs without `Runtime` when it is the only selected name. List both names for a usable SDK prefix.
- Duplicate names are not deduplicated. Normal file rules are usually harmless when repeated, but component-scoped `install(CODE)` and `install(SCRIPT)` side effects execute once per occurrence. Deduplicate lists before constructing the command.
- In the tested CMake 4.4.2 behavior, unknown names are ignored and the command succeeds. Known names in the same invocation still install; an unknown-only selection installs no payload. Automation that treats typos as errors must validate its requested names separately.
- Omitting `--component` is the only form here that selects unrelated components too. Supplying `Runtime Development` does not implicitly select `Documentation`, `Tools`, or any other component.

## CPack And Indirect Installs

The multi-value option belongs to direct `cmake --install` mode. It does not add a new `target_install_package()` or `export_cpack()` argument, and it is not an option to forward through CPack.

CPack selects components through its generated configuration and the active package generator. Continue to use `export_cpack(COMPONENTS ...)` for the package payload set and `DEFAULT_COMPONENTS` for installer defaults. Component dependency handling also remains generator-specific: archive component packages are independent payload slices, while this project maps supported relationships to native DEB and same-build RPM dependency metadata.

The CMake 4.4-gated [`proof_multi_component_install`](../tests/cmake/proof_multi_component_install_test.cmake) test covers a generated package with `Runtime` and `Development`, an unrelated `Documentation` component, a custom prefix, both CLI spellings, duplicates, unknown names, dependency non-resolution, a single-component install, an `EXCLUDE_FROM_ALL` rule, an unfiltered full install, and a controlled reproduction of the released 4.4.2 exit-status bug.
