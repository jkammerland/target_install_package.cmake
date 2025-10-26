# Repository Guidelines

## Project Structure & Module Organization
Core CMake entry points live at the root: `target_install_package.cmake`, `target_configure_sources.cmake`, and `export_cpack.cmake`. Reusable modules, include guards, and templates live under `cmake/`, while `docs/` captures reference material such as default install destinations. Use `examples/` for ready-made configurations (multi-target exports, C++20 modules), reserve `experimental/` for prototypes, and rely on the standalone `tests/` project to validate install flows with static, shared, and interface targets.

## Build, Test, and Development Commands
- `cmake -S . -B build -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON -Dtarget_install_package_BUILD_TESTS=ON` configures the workspace, enables install artifacts, and wires in the test project.
- `cmake --build build` builds helper libraries and regenerates configured headers.
- `ctest --test-dir build --output-on-failure` runs `tests/main.cpp` to exercise installed targets.
- `cmake --install build --prefix build/install` publishes install rules for inspection under `build/install/share/cmake/target_install_package`.
- `python - <<'PY' ...` (see `.github/workflows/ci.yml`) validates GitHub workflow YAML. CI enforces this via the `workflow-lint` job, so run it locally when editing files under `.github/workflows/`.

## Coding Style & Naming Conventions
Format CMake lists with two-space indentation, uppercase commands, and lowercase target names. Prefer descriptive snake_case for functions (`target_install_package`) and align related option blocks. Run `cmake-format -c .cmake-format.py <file>` before committing; the configuration enforces 200-character lines and preserves comments.

## Testing Guidelines
Expand the coverage in `tests/` when adding new install behaviors. Mirror existing naming patterns (`static1`, `component-devel`) and add assertions in `tests/main.cpp` for observable runtime effects. Always reconfigure with `-Dtarget_install_package_BUILD_TESTS=ON`, rebuild, run `ctest`, and, when relevant, re-run `cmake --install` to verify generated package metadata.

## Commit & Pull Request Guidelines
Write commit subjects in sentence case using present-tense verbs (e.g., `Add container packaging support`). Keep commits focused and call out touched modules (`cmake/`, `tests/`) in the body. Pull requests should summarize intent, list validation commands, link tracked issues, and include installer artifacts only when diagnosing packaging regressions.

## Documentation & Support
Consult `docs/` and `CPack-Tutorial.md` for install destination defaults and packaging workflows. Reference `documentation-audit-findings.md` for open follow-ups, and raise questions alongside reproduction steps when opening discussions or PRs.

## Continuous Integration Notes
- Avoid unquoted colons (e.g., `name: step: detail`) inside workflow step names; quote these strings so YAML parses correctly.
- The `workflow-lint` job fails the pipeline if any file in `.github/workflows/*.yml` cannot be parsed with PyYAML; fix syntax locally before pushing.
