# Universal Packaging CMake Modules

This directory contains the modular implementation of the universal packaging system, refactored to reduce code duplication and improve maintainability.

## Module Structure

### Core Module
- `packaging_utils.cmake` - Common utility functions used by all platform modules
  - `_parse_key_value_list()` - Parse key-value pairs from lists
  - `_extract_from_key_value_list()` - Extract specific values from key-value lists
  - `_process_template_file()` - Process template files with variable substitutions
  - `_create_platform_helper_scripts()` - Create platform-specific helper scripts
  - `_format_dependency_line()` - Format dependency lines for package files
  - `_build_substitution_map()` - Build substitution maps from multiple sources
  - `_validate_required_params()` - Validate required function parameters
  - `_list_to_space_string()` - Convert CMake lists to space-separated strings

### Platform Modules
- `packaging_arch.cmake` - Arch Linux packaging (PKGBUILD)
  - `generate_arch_packaging_templates()` - Main entry point
  - `_create_arch_pkgbuild()` - Create PKGBUILD templates
  - `_get_arch_platform_config()` - Platform configuration

- `packaging_alpine.cmake` - Alpine Linux packaging (APKBUILD)
  - `generate_alpine_packaging_templates()` - Main entry point
  - `_create_alpine_apkbuild()` - Create APKBUILD templates
  - `_get_alpine_platform_config()` - Platform configuration

- `packaging_nix.cmake` - Nix packaging (default.nix/flake.nix)
  - `generate_nix_packaging_templates()` - Main entry point
  - `_create_nix_expressions()` - Create Nix expressions
  - `_create_nix_default()` - Create default.nix
  - `_create_nix_flake()` - Create flake.nix
  - `_get_nix_platform_config()` - Platform configuration

## Usage

The main file `target_configure_universal_packaging.cmake` includes all these modules and provides the public API:

```cmake
# Include the main module
include(experimental/target_configure_universal_packaging.cmake)

# Configure universal packaging metadata
configure_universal_packaging(
  NAME "myproject"
  VERSION "1.0.0"
  DESCRIPTION "My project description"
  LICENSE "MIT"
  MAINTAINER "John Doe <john@example.com>"
  SOURCE_URL "https://github.com/user/project/archive/v@VERSION@.tar.gz"
)

# Configure platform-specific settings
configure_arch_packaging(
  DEPENDS "cmake" "gcc"
  MAKEDEPENDS "git"
)

configure_alpine_packaging(
  DEPENDS "cmake" "gcc"
  MAKEDEPENDS "git"
)

configure_nix_packaging(
  BUILD_INPUTS "cmake"
  FLAKE_ENABLED TRUE
)

# Generate packaging templates
generate_packaging_templates(
  PLATFORMS arch alpine nix
  OUTPUT_DIR "${CMAKE_BINARY_DIR}/packaging-templates"
  SOURCE_PACKAGES
)
```

## Benefits of Modular Structure

1. **Reduced Code Duplication**: Common patterns are extracted into reusable functions
2. **Easier Maintenance**: Platform-specific code is isolated in dedicated modules
3. **Better Organization**: Clear separation of concerns between platforms
4. **Extensibility**: New platforms can be added by creating new modules
5. **Testability**: Individual modules can be tested independently

## File Size Reduction

The refactoring reduced the main file from 1124 lines to 440 lines (61% reduction) by:
- Extracting ~200 lines per platform into separate modules
- Consolidating common utility functions
- Removing duplicate template processing code