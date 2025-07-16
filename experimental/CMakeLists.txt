cmake_minimum_required(VERSION 3.23)
project(test_universal_packaging VERSION 1.0.0)

# Include our universal packaging framework
include(target_configure_universal_packaging.cmake)

# Configure universal packaging metadata
configure_universal_packaging(
  NAME "myproject"
  VERSION "1.0.0"
  DESCRIPTION "My awesome C++ project with universal packaging"
  LICENSE "MIT"
  MAINTAINER "John Doe <john@example.com>"
  HOMEPAGE_URL "https://github.com/user/myproject"
  SOURCE_URL "https://github.com/user/myproject/archive/v@VERSION@.tar.gz"
  SOURCE_DIR "myproject-@VERSION@"
)

# Configure platform-specific settings
configure_arch_packaging(
  MAKEDEPENDS "cmake" "gcc"
  DEPENDS "glibc"
  ARCH "x86_64"
)

configure_alpine_packaging(
  MAKEDEPENDS "cmake" "gcc"
  DEPENDS "musl"
  ARCH "x86_64"
)

configure_nix_packaging(
  NATIVE_BUILD_INPUTS "gcc" "pkg-config"
  BUILD_INPUTS "glibc.dev"
  FLAKE_ENABLED
)

# Generate templates for all platforms
generate_packaging_templates(
  PLATFORMS arch alpine nix
  OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/packaging-templates"
  SOURCE_PACKAGES
  BINARY_PACKAGES
)

message(STATUS "Universal packaging test completed!")
message(STATUS "Check the 'packaging-templates' directory for generated files.")