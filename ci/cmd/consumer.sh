#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

ci_setup_ccache "${ci_root}"

usage() {
  cat <<'EOF'
Usage: ci/run.sh consumer [options]

Suites:
  consumer        Build+run `tests/consumer` against an installed root build (default)
  fetchcontent    Verify FetchContent integration with this repo
  package-manager Verify find_package() from an install prefix (vcpkg-like)
  integration     Run fetchcontent + package-manager suites

Builds and runs the `tests/consumer` project or related consumption/integration checks.

Options:
  --suite <name>          Suite to run (default: consumer)
  --preset <name>         Root preset to use for install dir (default: ci-release)
  --build-type <type>     Convenience: selects preset `ci-<lower(type)>`
  --compiler <name>       Compiler family (gcc/clang/cl), sets --cc/--cxx
  --cc <path>             C compiler for consumer configure
  --cxx <path>            C++ compiler for consumer configure
  --fmt-prefix <dir>      Optional fmt prefix to include in CMAKE_PREFIX_PATH
  --build-dir <dir>       Consumer build directory (default: build/ci-consumer/<preset>)
  --install-prefix <dir>  Install prefix used by package-manager suite
  --work-dir <dir>        Working directory for integration suites (default: build/ci-integration)
  -h, --help              Show help

Examples:
  ci/run.sh consumer --preset ci-release
  ci/run.sh consumer --build-type Release --compiler clang
  ci/run.sh consumer --suite integration --install-prefix install-artifacts/install --fmt-prefix fmt-install
EOF
}

suite="consumer"
preset=""
build_type=""
compiler_choice=""
cc=""
cxx=""
fmt_prefix=""
consumer_build_dir=""
install_prefix=""
work_dir="${ci_root}/build/ci-integration"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --suite)
      suite="${2:?}"
      shift 2
      ;;
    --preset)
      preset="${2:?}"
      shift 2
      ;;
    --build-type)
      build_type="${2:?}"
      shift 2
      ;;
    --compiler)
      compiler_choice="${2:?}"
      shift 2
      ;;
    --cc)
      cc="${2:?}"
      shift 2
      ;;
    --cxx)
      cxx="${2:?}"
      shift 2
      ;;
    --fmt-prefix)
      fmt_prefix="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --build-dir)
      consumer_build_dir="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --install-prefix)
      install_prefix="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --work-dir)
      work_dir="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

ci_require_cmd cmake

if [[ -z "${preset}" ]]; then
  if [[ -n "${build_type}" ]]; then
    preset="$(ci_preset_from_build_type "${build_type}")"
  else
    preset="ci-release"
  fi
fi

if [[ -n "${compiler_choice}" && ( -z "${cc}" || -z "${cxx}" ) ]]; then
  IFS=';' read -r cc cxx <<<"$(ci_compilers_from_choice "${compiler_choice}")"
fi

bt="$(ci_build_type_from_preset "${preset}")"
if [[ -z "${bt}" ]]; then
  bt="${build_type:-Release}"
fi

if [[ -z "${consumer_build_dir}" ]]; then
  if [[ "${preset}" == ci-* ]]; then
    consumer_build_dir="${ci_root}/build/ci-consumer/${preset#ci-}"
  else
    consumer_build_dir="${ci_root}/build/ci-consumer/${preset}"
  fi
fi

if [[ -z "${fmt_prefix}" && -d "${ci_root}/build/ci-deps/fmt-install" ]]; then
  fmt_prefix="${ci_root}/build/ci-deps/fmt-install"
elif [[ -z "${fmt_prefix}" && -d "${ci_root}/fmt-install" ]]; then
  fmt_prefix="${ci_root}/fmt-install"
fi

osx_sysroot_args=()
if ci_is_macos && (ci_is_homebrew_llvm_compiler "${cc}" || ci_is_homebrew_llvm_compiler "${cxx}"); then
  if sdkroot="$(ci_macos_sdkroot)"; then
    export SDKROOT="${sdkroot}"
    osx_sysroot_args+=("-DCMAKE_OSX_SYSROOT=$(ci_path_for_cmake "${sdkroot}")")
    ci_log "macOS SDKROOT: ${sdkroot}"
  else
    ci_warn "xcrun not found; Homebrew LLVM may not find the macOS SDK"
  fi
fi

prefix_arg_for() {
  local prefixes=()
  for p in "$@"; do
    [[ -n "${p}" ]] || continue
    prefixes+=("$(ci_path_for_cmake "${p}")")
  done
  ci_join_by ';' "${prefixes[@]}"
}

run_consumer_suite() {
  install_dir="$(ci_install_dir_from_preset "${ci_root}" "${preset}")"
  if [[ -z "${install_dir}" ]]; then
    ci_die "Unable to infer install dir for preset '${preset}'"
  fi

  local prefixes=()
  prefixes+=("${install_dir}")
  if [[ -n "${fmt_prefix}" && -d "${fmt_prefix}" ]]; then
    prefixes+=("${fmt_prefix}")
  fi
  prefix_arg="$(prefix_arg_for "${prefixes[@]}")"

  ci_log "==> Configure consumer"
  cmake --log-level=DEBUG -S "${ci_root}/tests/consumer" -B "${consumer_build_dir}" -G Ninja \
    ${cc:+-DCMAKE_C_COMPILER=${cc}} \
    ${cxx:+-DCMAKE_CXX_COMPILER=${cxx}} \
    -DCMAKE_BUILD_TYPE="${bt}" \
    -DPROJECT_LOG_COLORS=ON \
    "${osx_sysroot_args[@]}" \
    -DCMAKE_PREFIX_PATH="${prefix_arg}"

  ci_log "==> Build consumer"
  cmake --build "${consumer_build_dir}"

  ci_log "==> Run consumer"
  if ci_is_windows; then
    "${consumer_build_dir}/consumer.exe"
  else
    "${consumer_build_dir}/consumer"
  fi
}

run_fetchcontent_suite() {
  local fc_dir="${work_dir}/fetchcontent"
  rm -rf "${fc_dir}"
  mkdir -p "${fc_dir}"

  cat >"${fc_dir}/CMakeLists.txt" <<CMAKE
cmake_minimum_required(VERSION 3.25)
project(test_fetchcontent VERSION 0.0.1)

find_package(fmt REQUIRED)

include(FetchContent)
FetchContent_Declare(
  target_install_package
  SOURCE_DIR "${ci_root}"
)
FetchContent_MakeAvailable(target_install_package)

add_library(test_lib INTERFACE)
target_include_directories(test_lib INTERFACE
  \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>
  \$<BUILD_INTERFACE:\${PROJECT_BINARY_DIR}/include>
  \$<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}>
)

target_install_package(test_lib NAMESPACE Test::)
CMAKE

  prefix_arg=""
  if [[ -n "${fmt_prefix}" ]]; then
    prefix_arg="$(prefix_arg_for "${fmt_prefix}")"
  fi

  ci_log "==> FetchContent integration configure"
  cmake_args=(
    --log-level=DEBUG
    -S "${fc_dir}"
    -B "${fc_dir}/build"
    -G Ninja
  )
  if [[ -n "${cc}" ]]; then
    cmake_args+=("-DCMAKE_C_COMPILER=${cc}")
  fi
  if [[ -n "${cxx}" ]]; then
    cmake_args+=("-DCMAKE_CXX_COMPILER=${cxx}")
  fi
  cmake_args+=("${osx_sysroot_args[@]}")
  if [[ -n "${prefix_arg}" ]]; then
    cmake_args+=("-DCMAKE_PREFIX_PATH=${prefix_arg}")
  fi
  cmake_args+=("-DPROJECT_LOG_COLORS=ON")

  cmake "${cmake_args[@]}"

  ci_log "==> FetchContent integration build"
  cmake --build "${fc_dir}/build"
}

run_package_manager_suite() {
  if [[ -z "${install_prefix}" ]]; then
    ci_die "--install-prefix is required for package-manager suite"
  fi

  local pm_dir="${work_dir}/package-manager"
  rm -rf "${pm_dir}"
  mkdir -p "${pm_dir}"

  cat >"${pm_dir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.25)
project(test_package_manager_consumer VERSION 0.0.1)

find_package(target_install_package CONFIG REQUIRED)

add_executable(consumer main.cpp)
target_install_package(consumer)
CMAKE

  cat >"${pm_dir}/main.cpp" <<'CPP'
#include <iostream>
int main() {
  std::cout << "Package manager integration test passed!\n";
  return 0;
}
CPP

  prefixes=("${install_prefix}")
  if [[ -n "${fmt_prefix}" && -d "${fmt_prefix}" ]]; then
    prefixes+=("${fmt_prefix}")
  fi
  prefix_arg="$(prefix_arg_for "${prefixes[@]}")"

  ci_log "==> Package-manager integration configure"
  cmake --log-level=DEBUG -S "${pm_dir}" -B "${pm_dir}/build" -G Ninja \
    -DPROJECT_LOG_COLORS=ON \
    "${osx_sysroot_args[@]}" \
    -DCMAKE_PREFIX_PATH="${prefix_arg}"

  ci_log "==> Package-manager integration build"
  cmake --build "${pm_dir}/build"
}

case "${suite}" in
  consumer) run_consumer_suite ;;
  fetchcontent) run_fetchcontent_suite ;;
  package-manager) run_package_manager_suite ;;
  integration)
    run_fetchcontent_suite
    run_package_manager_suite
    ;;
  *)
    usage >&2
    ci_die "Unknown suite: ${suite}"
    ;;
esac
