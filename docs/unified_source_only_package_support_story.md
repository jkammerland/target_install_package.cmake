# User Story: Unified source-only package support in `target_install_package()`

## Summary

As a package author, I want `target_install_package()` to support **source-only** packages, alongside binary and header-only packages, so that I can ship small implementation libraries, configuration-sensitive code, and hybrid SDKs through **one packaging API**, while keeping the result consumable through normal `find_package()` workflows.

## Context

`target_install_package.cmake` already presents itself as a single-function packaging utility that generates installable CMake packages, supports file sets and C++20 modules, and keeps package setup centered on the target model rather than a second packaging DSL. PR #49 is already moving in that same direction: it adds `SOURCE_FILES`, documents “first-class source-only interface packages,” and adds examples for a basic source-only package, a hybrid SDK, and a source-package-modules example. The PR docs describe the intended behavior as: install the implementation sources under `share/<package>/` by default and publish them through `INTERFACE_SOURCES` on the installed imported target, so the consumer compiles them with its own toolchain and flags. ([GitHub][3])

This is well aligned with CMake’s target model. `add_library(<name> INTERFACE)` creates a target with usage requirements but no produced library artifact, `target_sources(... INTERFACE ...)` populates `INTERFACE_SOURCES`, and `INTERFACE_SOURCES` are compiled into consuming targets. Current CMake docs also explicitly note that exporting targets with `INTERFACE_SOURCES` is supported, and that `INTERFACE` / `PUBLIC` file sets can be installed and exported. ([CMake][4])

CMake 4.3 also makes CPS a first-class package format: `find_package()` can now search for and import `.cps` files, `install(PACKAGE_INFO)` and `export(PACKAGE_INFO)` generate CPS package descriptions, and `project()` metadata such as `VERSION`, `COMPAT_VERSION`, `SPDX_LICENSE`, `DESCRIPTION`, and `HOMEPAGE_URL` can be inherited when generating CPS. CMake’s config-mode search now tends to prefer CPS files over CMake-script package configs in many cases, and `.cps` files are searched in `/cps/` locations rather than the normal `cmake/` config-package paths. ([CMake][5])

At the same time, CPS is **not** a perfect semantic match for source-only packages. The CPS schema models packages as components with usage requirements such as include directories, compile features, compile/link requirements, and, for non-interface components, artifact locations. An `interface` component explicitly has **no location** and is meant for a consumable component without an associated artifact. That is a natural fit for header-only or virtual/feature components, but it does **not** cleanly express the CMake-specific idea of “ship these `.cpp` files and have each consumer compile them via `INTERFACE_SOURCES`.” That means source-only support should be **CMake-first** and **CPS-aware**, not CPS-dependent. ([CPS Organization][6])

I also verified locally with CMake 3.31 that an installed exported `INTERFACE IMPORTED` target can carry relocated `INTERFACE_SOURCES` pointing into the install tree, so the CMake-package route is technically viable today even before CMake 4.3 CPS is brought into the picture.

## User story

As a maintainer of `target_install_package.cmake`, I want to add first-class support for source-only packages to the existing packaging workflow, so that package authors can publish:

* binary packages,
* header-only packages,
* source-only packages,
* and hybrid SDK packages

through one unified target-centric API, without having to switch to a separate “source package” function or a second packaging model.

## Desired outcome

The feature should make it straightforward to declare that some package content is **consumer-built source payload**, while preserving the existing mental model:

* headers remain headers,
* modules remain modules,
* binary artifacts remain binary artifacts,
* and source-only implementation files become an explicit, documented package payload rather than an ad hoc extra file install.

The primary consumption path should remain the generated **CMake package config** because that is the mechanism that can faithfully recreate imported targets with `INTERFACE_SOURCES`. CPS support should be treated as an additional export surface when it is semantically accurate, not as the sole source of truth for source-only packages. ([CMake][2])

## Suggested design direction (non-binding)

### 1. Keep one entry point

Prefer extending `target_install_package()` rather than adding a sibling like `target_install_source_package()`. The unified API is one of the project’s strengths already, and the PR direction with `SOURCE_FILES` is consistent with that philosophy. A source-only package should feel like one more package shape handled by the same function, not a separate subsystem. ([GitHub][3])

### 2. Treat “source-only” as a package shape, not a target type replacement

A good working rule is:

* **header-only**: `INTERFACE` target with headers / usage requirements only
* **source-only**: `INTERFACE` target whose package payload also includes consumer-built implementation sources
* **hybrid**: package export that combines prebuilt targets and source-only extension targets in one SDK

That matches both CMake’s `INTERFACE` target model and the examples already added in PR #49. For v1, it is reasonable to support consumer-built sources only for `INTERFACE` targets and emit a clear diagnostic for other target types. ([CMake][4])

### 3. Make the API additive, not modal

A good default direction is to keep source-only support as an **additive capability** of the existing API. The current `SOURCE_FILES` / `SOURCE_DESTINATION` idea is a strong candidate because it composes naturally with existing arguments such as `NAMESPACE`, `ADDITIONAL_FILES`, `INCLUDE_ON_FIND_PACKAGE`, `PUBLIC_DEPENDENCIES`, and module-related behavior. A more explicit “mode” argument could still exist later for diagnostics or policy, but authors should not be forced to choose between completely different APIs. ([GitHub][1])

### 4. Preserve relative layout and keep source payload out of the include tree

The default install destination for consumer-built source payload should remain something like `${CMAKE_INSTALL_DATADIR}/<package>` (today documented in the PR as `share/<package>`). That keeps implementation sources out of public include directories, preserves a clean split between “included by the compiler” and “compiled by the consumer,” and matches the examples/docs already drafted. Relative source layout should be preserved under that root. ([GitHub][1])

### 5. The installed imported target should be the source of truth

The installed imported target should expose the same usage requirements a normal package would expose:

* include directories,
* compile features,
* compile definitions/options,
* transitive link dependencies,
* and, for source-only packages, relocated `INTERFACE_SOURCES`.

That keeps source-only packages target-centric and lets consumers use them through the same `find_package()` + `target_link_libraries()` flow as other packages. CMake’s documented behavior supports this model directly. ([CMake][2])

### 6. Make CPS support explicit and conservative

For CMake 4.3+, CPS emission should be considered **optional and best-effort** for source-only packages.

Suggested policy:

* keep generating normal `Config.cmake` packages as the authoritative mechanism;
* generate CPS automatically for package shapes that map cleanly;
* for pure source-only packages, either skip CPS entirely by default or emit it only when you can do so without inventing semantics that CPS does not actually model;
* if CPS is emitted, install it to a real CPS search location, not the current `share/cmake/<package>` config location.

This follows directly from how CMake 4.3 searches for CPS packages and from the fact that CPS models interface usage requirements and artifact locations, but not a first-class “consumer compiles these installed `.cpp` sources” payload. ([CMake][7])

### 7. Treat the modules variant as a separate compatibility tier

PR #49’s `source-package-modules` example is useful, but it already shows that modules need extra handling. The helper file in the PR notes that imported `INTERFACE` targets do not preserve `CXX_EXTENSIONS`, then patches the imported target at `find_package()` time by adding compile options and a `FILE_SET CXX_MODULES`. That is a real signal that the modules case is more delicate than ordinary source-only `.cpp` consumption. On top of that, current CMake module docs still list important limitations for imported targets, especially around BMIs and Visual Studio generators. Module-based source packages should therefore be documented as **experimental / toolchain-gated** even if the non-module source-only flow is promoted to first-class status. ([GitHub][8])

## Acceptance criteria

### Functional behavior

* A package author can publish a source-only package through the same `target_install_package()` entry point used for binary and header-only packages.
* The supported v1 shape is an `INTERFACE` target plus an explicit consumer-built source payload.
* Installed source files are copied into a development-oriented destination outside the public include tree, with relative layout preserved.
* The installed imported target exposes relocated `INTERFACE_SOURCES`, so consumers build the shipped implementation files with their own toolchain and target properties.
* Headers, file sets, compile features, include directories, definitions, and transitive dependencies continue to behave exactly as they do for other interface packages. ([CMake][2])

### Unified API expectations

* There is still one primary packaging function.
* Source-only support is expressed as an additive capability, not a separate packaging subsystem.
* Hybrid packages are possible: one package export may contain prebuilt targets plus source-only extension targets or umbrella targets, as shown by the PR examples. ([GitHub][1])

### Documentation expectations

* The docs explain **when** source-only packaging is appropriate: small implementation libraries, configuration-sensitive code, or extension layers meant to be compiled in the consumer build.
* The docs also explain when it is **not** appropriate: large libraries, ABI-stable binary libraries, or cases where duplicate compilation/linkage would be problematic.
* The docs make clear that each consumer target compiles the package’s `INTERFACE_SOURCES`; this is not a replacement for static/shared library packaging. The PR already says this and it should remain front-and-center. ([GitHub][1])

### Testing expectations

* Regression coverage exists for a minimal source-only package.
* Regression coverage exists for a root-level or top-level export case.
* Regression coverage exists for a hybrid SDK case.
* Module-specific coverage remains separate and is allowed to be toolchain/generator-conditional. ([GitHub][9])

### CPS expectations

* CPS support is version-gated to CMake 4.3+.
* CPS generation uses `install(PACKAGE_INFO)` / `export(PACKAGE_INFO)` rather than relying on the distributor-focused `CMAKE_INSTALL_EXPORTS_AS_PACKAGE_INFO` fallback.
* `.cps` files, when generated, are installed to CPS search paths rather than the normal `cmake/` config path.
* Source-only packages do **not** ship misleading CPS metadata that claims a stronger or more portable source-consumption model than CPS actually provides. ([CMake][5])

## Sharp edges to document up front

### 1. Per-consumer compilation is the feature and the hazard

`INTERFACE_SOURCES` are compiled into consuming targets. That is why source-only packaging works, but it also means the same implementation sources may be compiled multiple times in one consumer project. This can be exactly what you want for configuration-sensitive code, but it can also create duplicate-definition or ODR-style problems if the package is linked from multiple targets that later end up in the same final binary. This should be documented as a core semantic property, not a footnote. ([CMake][2])

### 2. CPS is not the semantic center for this feature

CPS is excellent for describing packages in a build-system-agnostic way, and CMake 4.3 clearly wants it to become a first-class interchange format. But the CPS schema’s `interface` component is still “a component without a location,” not “a bundle of consumer-compiled `.cpp` implementation files.” So source-only support should land first as a robust CMake package capability, then gain CPS coverage only where the mapping is honest and useful. ([CMake][5])

### 3. Modules remain the highest-friction variant

CMake 3.28+ does support `FILE_SET CXX_MODULES`, installation/export of module sets, and CMake 4.3’s CPS machinery has a `CXX_MODULES_DIRECTORY` option plus CPS `cpp_module_metadata` support. But the current module docs still call out limitations for imported targets and for Visual Studio generators, and your PR already needs a `find_package()`-time helper to repair module-related behavior on the imported target. That makes module-based source packages a valid direction, but not the baseline success case for the story. ([CMake][10])

### 4. Naming matters more once CPS is introduced

CMake’s CPS integration assumes imported targets are prefixed with `<package-name>::`, and when CMake resolves CPS transitive requirements through a CMake-script package it validates required imported targets using that naming convention. If CPS support is added later, package names, exported target names, and component names need to stay aligned enough that source-only or hybrid exports do not become naming-translation exercises. ([CMake][11])

## Implementation note

If you want the implementation to stay incremental, the cleanest sequencing is:

1. land the CMake-native source-only behavior as the authoritative package path;
2. document hybrid/source-only/module use cases clearly;
3. then add CPS generation as a follow-up layer for package shapes that have a faithful CPS mapping.

That sequence matches both the current PR direction and the shape of the upstream CMake/CPS feature set. ([GitHub][1])

## References

* `target_sources()` populates `INTERFACE_SOURCES`, and those sources are compiled into consumers; exporting targets with `INTERFACE_SOURCES` is supported. ([CMake][12])
* `add_library(INTERFACE)` creates a target with usage requirements and no produced library artifact, but it may still be installed/exported. ([CMake][4])
* PR #49 documents source-only support via `SOURCE_FILES`, default install under `share/<package>/`, plus `basic-source-package`, `sdk-hybrid`, and `source-package-modules` examples. ([GitHub][1])
* CMake 4.3 adds first-class CPS support: `find_package()` can search/import `.cps`, and `install()` / `export()` gained `PACKAGE_INFO`. ([CMake][5])
* `find_package()` tends to prefer CPS files, searches `.cps` names in config mode, and only looks for `.cps` inside `/cps/` search paths. ([CMake][7])
* `install(PACKAGE_INFO)` / `export(PACKAGE_INFO)` provide CPS metadata, default target selection, metadata inheritance, appendices, module directory support, and note that generator-expression support is limited compared with CMake-script exports. ([CMake][11])
* The CPS schema models includes, compile features, compile/link requirements, module metadata, and interface components without a location. ([CPS Organization][6])
* CMake’s current C++ modules docs still list limitations for imported targets / BMIs, especially with Visual Studio generators. ([CMake][13])

The standalone file is ready to paste into an issue or PR description.

[1]: https://github.com/jkammerland/target_install_package.cmake/pull/49/files "https://github.com/jkammerland/target_install_package.cmake/pull/49/files"
[2]: https://cmake.org/cmake/help/latest/prop_tgt/INTERFACE_SOURCES.html "https://cmake.org/cmake/help/latest/prop_tgt/INTERFACE_SOURCES.html"
[3]: https://raw.githubusercontent.com/jkammerland/target_install_package.cmake/master/README.md "https://raw.githubusercontent.com/jkammerland/target_install_package.cmake/master/README.md"
[4]: https://cmake.org/cmake/help/latest/command/add_library.html "https://cmake.org/cmake/help/latest/command/add_library.html"
[5]: https://cmake.org/cmake/help/latest/release/4.3.html "https://cmake.org/cmake/help/latest/release/4.3.html"
[6]: https://cps-org.github.io/cps/schema.html "https://cps-org.github.io/cps/schema.html"
[7]: https://cmake.org/cmake/help/latest/command/find_package.html "https://cmake.org/cmake/help/latest/command/find_package.html"
[8]: https://raw.githubusercontent.com/jkammerland/target_install_package.cmake/feat/interface_sources/examples/source-package-modules/cmake/source_math_modules-modules.cmake "https://raw.githubusercontent.com/jkammerland/target_install_package.cmake/feat/interface_sources/examples/source-package-modules/cmake/source_math_modules-modules.cmake"
[9]: https://github.com/jkammerland/target_install_package.cmake/pull/49 "https://github.com/jkammerland/target_install_package.cmake/pull/49"
[10]: https://cmake.org/cmake/help/latest/prop_tgt/INTERFACE_CXX_MODULE_SETS.html "https://cmake.org/cmake/help/latest/prop_tgt/INTERFACE_CXX_MODULE_SETS.html"
[11]: https://cmake.org/cmake/help/latest/command/install.html "https://cmake.org/cmake/help/latest/command/install.html"
[12]: https://cmake.org/cmake/help/latest/command/target_sources.html "https://cmake.org/cmake/help/latest/command/target_sources.html"
[13]: https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html "https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html"
