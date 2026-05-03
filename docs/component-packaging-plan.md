# Component Packaging Plan

This plan records the v7 component contract and the fixes needed to make the implementation match it.

## Contract

- `target_install_package(... COMPONENT <name>)` names runtime payload only.
- SDK payload for an export installs to one shared `Development` component.
- Runtime payload means executables, shared-library runtime files, Windows DLLs, and module-library runtime files.
- Static libraries, interface libraries, and header-only targets are SDK-only unless another target registered through this wrapper puts runtime payload in the same component. Standalone manual install components need explicit `export_cpack(COMPONENTS ...)` inclusion.
- Raw `cmake --install --component <name>` installs exactly that component and does not resolve dependencies.
- Archive component packages are payload archives and do not enforce dependencies.
- Native package-manager dependency behavior is generator-specific. `export_cpack()` should not promise generic DEB/RPM dependency solving unless it implements and tests the generator-specific metadata.
- CMake package components are dependency gates/found flags, not target-visibility or install-payload selectors.
- Separate `EXPORT_NAME`s are the escape hatch for independently installable SDK subsets.

## Implementation Plan

1. Make runtime component registration payload-aware.
   - Register runtime components only for targets with runtime artifacts.
   - Do not create empty runtime packages for static or interface targets.
   - Keep `Development` registered for SDK/config payload.

2. Derive CPack defaults from detected payload components.
   - Validate explicit `DEFAULT_COMPONENTS` against `COMPONENTS`.
   - If defaults are implicit, use detected runtime payload components.
   - If no runtime payload component exists, default to `Development`.
   - Express selected defaults using CPack's per-component `DISABLED` metadata; do not emit unsupported default-list variables.

3. Make explicit single-component CPack filtering work.
   - Treat explicit `COMPONENTS <one-component>` as a component-install request.
   - This prevents `export_cpack(COMPONENTS Development)` from creating a full unfiltered archive.

4. Add export alias validation.
   - Fail before install generation if two targets in one export resolve to the same exported target name.

5. Add regression tests.
   - Static-only named component must produce `Development` only, not an empty runtime package.
   - Explicit one-component `export_cpack(COMPONENTS Development)` must package only that component.
   - Duplicate exported aliases must fail configure/finalize.
   - Existing unified `Development` tests must remain green.

6. Audit docs and examples.
   - Distinguish raw component installs, archive extraction, and native package-manager installs.
   - State that shared-library consumers need runtime components plus `Development` for raw installs.
   - Do not claim generic RPM dependency generation.
   - Keep DEB/RPM dependency mapping as a separate constrained follow-up unless implemented and tested.

7. Validate and review.
   - Run focused proof tests.
   - Run the full CTest suite.
   - Run example/package smoke tests where relevant.
   - Run a final Codex review pass on the implemented plan before pushing.

## Explicit Non-Goals For This Patch

- Do not restore generated `<Component>_Development` components.
- Do not duplicate shared-library runtime files into `Development`.
- Do not implement a generic RPM `Requires` mapper without a stable package-name policy and tests.
- Do not make `find_package(... COMPONENTS ...)` hide exported targets.
