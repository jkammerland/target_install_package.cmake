#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

ci_setup_ccache "${ci_root}"

usage() {
  cat <<'EOF'
Usage: ci/run.sh examples [options]

Suites:
  single                 Configure/build/test examples via examples/CMakePresets.json (default)
  multi                  Run multi-config examples build + integration verification
  consume-multi-config   Build basic-* multi-config installs and verify consumer link lines
  consume-single-config  Build basic-* single-config installs and verify consumer link lines
  consume-fhs-combined   Build basic-* FHS combined installs and run consumers

Options:
  --suite <name>         Suite to run (default: single)
  --preset <name>        Examples preset (default: ci-release)
  --build-type <type>    Convenience: selects preset `ci-<lower(type)>`
  --compiler <name>      Compiler family (gcc/clang/cl), sets --cc/--cxx
  --cc <path>            C compiler for configure
  --cxx <path>           C++ compiler for configure
  --use-fetchcontent     Force FetchContent dependency mode (default on GitHub Actions)
  --no-fetchcontent      Disable FetchContent dependency mode (default locally)
  -h, --help             Show help

Examples:
  ci/run.sh examples --build-type Release
  ci/run.sh examples --suite multi --build-type Debug --compiler gcc-14
EOF
}

suite="single"
preset=""
build_type=""
compiler_choice=""
cc=""
cxx=""

# Dependency mode:
# - CI default: FetchContent (matches GitHub workflow)
# - Local default: prefer system packages (no network required)
use_fetchcontent=""

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
    --use-fetchcontent)
      use_fetchcontent="true"
      shift
      ;;
    --no-fetchcontent)
      use_fetchcontent="false"
      shift
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

ci_require_cmd cmake
ci_require_cmd ctest

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

if [[ -z "${use_fetchcontent}" ]]; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    use_fetchcontent="true"
  else
    use_fetchcontent="false"
  fi
fi

if [[ -n "${cc}" ]]; then
  export CC="${cc}"
fi
if [[ -n "${cxx}" ]]; then
  export CXX="${cxx}"
fi
if [[ -n "${build_type}" ]]; then
  export CMAKE_BUILD_TYPE="${build_type}"
fi

ensure_cxxopts_stub_prefix() {
  local prefix="${ci_root}/build/ci-deps/stub-prefix"
  local cmake_dir="${prefix}/share/cmake/cxxopts"

  mkdir -p "${cmake_dir}"
  cat >"${cmake_dir}/cxxoptsConfig.cmake" <<'CMAKE'
if(NOT TARGET cxxopts::cxxopts)
  add_library(cxxopts::cxxopts INTERFACE IMPORTED)
endif()
set(cxxopts_FOUND TRUE)
CMAKE

  cat >"${cmake_dir}/cxxoptsConfigVersion.cmake" <<'CMAKE'
set(PACKAGE_VERSION "3.1.1")
if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
CMAKE

  printf '%s\n' "${prefix}"
}

run_single_suite() {
  local bt exe build_dir preset_suffix
  bt="$(ci_build_type_from_preset "${preset}")"
  if [[ -z "${bt}" ]]; then
    bt="${build_type:-Release}"
  fi

  if [[ "${preset}" == ci-* ]]; then
    preset_suffix="${preset#ci-}"
  else
    ci_die "examples single suite expects a ci-* preset (got '${preset}')"
  fi

  build_dir="${ci_root}/build/examples/${preset_suffix}"

  cfg_args=()
  if [[ -n "${cc}" ]]; then
    cfg_args+=("-DCMAKE_C_COMPILER=${cc}")
  fi
  if [[ -n "${cxx}" ]]; then
    cfg_args+=("-DCMAKE_CXX_COMPILER=${cxx}")
  fi
  if [[ "${use_fetchcontent}" == "true" ]]; then
    cfg_args+=("-DEXAMPLES_USE_FETCHCONTENT_DEPS=ON")
  else
    stub_prefix="$(ensure_cxxopts_stub_prefix)"
    cfg_args+=("-DEXAMPLES_USE_FETCHCONTENT_DEPS=OFF")
    cfg_args+=("-DCMAKE_PREFIX_PATH=$(ci_path_for_cmake "${stub_prefix}")")
  fi

  ci_log "==> Configure examples (${preset})"
  cmake -S "${ci_root}/examples" --preset "${preset}" "${cfg_args[@]}"

  ci_log "==> Build examples (${build_dir})"
  cmake --build "${build_dir}"

  ci_log "==> Test examples (${build_dir})"
  ctest --test-dir "${build_dir}" --output-on-failure

  if ci_is_windows; then
    exe="${build_dir}/test_examples_main.exe"
  else
    exe="${build_dir}/test_examples_main"
  fi

  ci_log "==> Verify binary linking (${bt})"
  "${ci_root}/examples/verify_binary_linking.sh" "${exe}" "${bt}" "$(ci_uname_s)"
}

run_multi_suite() {
  local integration_dir configs cmake_config_types

  ci_log "==> Build all examples (multi-config)"
  "${ci_root}/examples/build_all_examples.sh" --multi-config

  ci_log "==> Verify multi-config artifacts"
  bash "${ci_dir}/lib/verify_examples_multiconfig.sh"

  integration_dir="${ci_root}/build/examples/multi-config-integration"
  rm -rf "${integration_dir}"
  mkdir -p "${integration_dir}"

  if ci_is_linux && [[ "${cc}" == *gcc-14* || "${compiler_choice}" == "gcc-14" ]]; then
    cmake_config_types="Debug;Release;RelWithDebInfo"
    configs=("Debug" "Release" "RelWithDebInfo")
  else
    cmake_config_types="Debug;Release;MinSizeRel;RelWithDebInfo"
    configs=("Debug" "Release" "MinSizeRel" "RelWithDebInfo")
  fi

  cfg_args=()
  if [[ -n "${cc}" ]]; then
    cfg_args+=("-DCMAKE_C_COMPILER=${cc}")
  fi
  if [[ -n "${cxx}" ]]; then
    cfg_args+=("-DCMAKE_CXX_COMPILER=${cxx}")
  fi
  if [[ "${use_fetchcontent}" == "true" ]]; then
    cfg_args+=("-DEXAMPLES_USE_FETCHCONTENT_DEPS=ON")
  else
    stub_prefix="$(ensure_cxxopts_stub_prefix)"
    cfg_args+=("-DEXAMPLES_USE_FETCHCONTENT_DEPS=OFF")
    cfg_args+=("-DCMAKE_PREFIX_PATH=$(ci_path_for_cmake "${stub_prefix}")")
  fi

  ci_log "==> Configure examples integration (Ninja Multi-Config)"
  cmake -S "${ci_root}/examples" -B "${integration_dir}" -G "Ninja Multi-Config" \
    -DCMAKE_CONFIGURATION_TYPES="${cmake_config_types}" \
    -DRUN_BUILD_ALL_EXAMPLES=OFF \
    --log-level=VERBOSE \
    "${cfg_args[@]}"

  for cfg in "${configs[@]}"; do
    ci_log "==> Build+test examples integration (${cfg})"
    cmake --build "${integration_dir}" --config "${cfg}"
    ctest --test-dir "${integration_dir}" --output-on-failure --build-config "${cfg}"
  done

  ci_log "==> Verify binary linking (multi-config)"
  for cfg in "${configs[@]}"; do
    if ci_is_windows; then
      exe="${integration_dir}/${cfg}/test_examples_main.exe"
    else
      exe="${integration_dir}/${cfg}/test_examples_main"
    fi
    "${ci_root}/examples/verify_binary_linking.sh" "${exe}" "${cfg}" "$(ci_uname_s)"
  done
}

run_consume_multi_config_suite() {
  ci_python_bin="$(ci_python)" || ci_die "Missing required command: python (or python3)"
  ci_log "==> Build+install basic-static (multi-config)"
  (cd "${ci_root}/examples/basic-static" && \
    cmake -S . -B build -G "Ninja Multi-Config" \
      -DCMAKE_INSTALL_PREFIX=./build/install \
      -DTIP_INSTALL_LAYOUT=split_all \
      -DCMAKE_CONFIGURATION_TYPES="Debug;Release;MinSizeRel;RelWithDebInfo" && \
    for cfg in Debug Release MinSizeRel RelWithDebInfo; do
      cmake --build build --config "${cfg}"
      cmake --install build --config "${cfg}"
    done)

  ci_log "==> Build+install basic-shared (multi-config)"
  (cd "${ci_root}/examples/basic-shared" && \
    cmake -S . -B build -G "Ninja Multi-Config" \
      -DCMAKE_INSTALL_PREFIX=./build/install \
      -DTIP_INSTALL_LAYOUT=split_all \
      -DCMAKE_CONFIGURATION_TYPES="Debug;Release;MinSizeRel;RelWithDebInfo" && \
    for cfg in Debug Release MinSizeRel RelWithDebInfo; do
      cmake --build build --config "${cfg}"
      cmake --install build --config "${cfg}"
    done)

  ci_log "==> Configure consumer (multi-config)"
  consumer_dir="${ci_root}/build/ci-consumer/multi-config"
  rm -rf "${consumer_dir}"
  mkdir -p "${consumer_dir}"
  cat >"${consumer_dir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.23)
project(multiconfig_consumer LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
find_package(math_lib CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE Math::math_lib Utils::string_utils)
CMAKE
  cat >"${consumer_dir}/main.cpp" <<'CPP'
#include <iostream>
int main(){ std::cout << "ok\n"; return 0; }
CPP

  prefix_math="$("${ci_python_bin}" -c 'import os; print(os.path.abspath(os.path.join("examples","basic-static","build","install")))' )"
  prefix_utils="$("${ci_python_bin}" -c 'import os; print(os.path.abspath(os.path.join("examples","basic-shared","build","install")))' )"
  prefix_paths="$(ci_join_by ';' "$(ci_path_for_cmake "${prefix_math}")" "$(ci_path_for_cmake "${prefix_utils}")")"

  cmake -S "${consumer_dir}" -B "${consumer_dir}/build" -G "Ninja Multi-Config" \
    -DCMAKE_CONFIGURATION_TYPES="Debug;Release;MinSizeRel;RelWithDebInfo" \
    -DCMAKE_PREFIX_PATH="${prefix_paths}"

  ci_log "==> Build Release and assert link uses release libs"
  release_log="${consumer_dir}/build_release.log"
  (cmake --build "${consumer_dir}/build" --config Release -v | tee "${release_log}")
  grep -E "[\\\\/](release)[\\\\/](lib|lib64)" "${release_log}"
  if grep -E "[\\\\/](debug)[\\\\/](lib|lib64)" "${release_log}"; then
    ci_die "Found debug libs in Release link!"
  fi

  ci_log "==> Build Debug and assert link uses debug libs"
  debug_log="${consumer_dir}/build_debug.log"
  (cmake --build "${consumer_dir}/build" --config Debug -v | tee "${debug_log}")
  grep -E "[\\\\/](debug)[\\\\/](lib|lib64)" "${debug_log}"
  if grep -E "[\\\\/](release)[\\\\/](lib|lib64)" "${debug_log}"; then
    ci_die "Found release libs in Debug link!"
  fi
}

run_consume_single_config_suite() {
  ci_log "==> Build+install basic-* (single-config, split_all)"
  for ex in basic-static basic-shared; do
    (cd "${ci_root}/examples/${ex}" && \
      cmake -S . -B build-rel -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./build/install -DTIP_INSTALL_LAYOUT=split_all && \
      cmake --build build-rel && \
      cmake --install build-rel && \
      cmake -S . -B build-dbg -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=./build/install -DTIP_INSTALL_LAYOUT=split_all && \
      cmake --build build-dbg && \
      cmake --install build-dbg)
  done

  prefixes="$(ci_join_by ';' "$(ci_path_for_cmake "${ci_root}/examples/basic-static/build/install")" "$(ci_path_for_cmake "${ci_root}/examples/basic-shared/build/install")")"

  for cfg in Release Debug; do
    cfg_lc="$(ci_lower "${cfg}")"
    consumer_dir="${ci_root}/build/ci-consumer/single-config/${cfg_lc}"
    rm -rf "${consumer_dir}"
    mkdir -p "${consumer_dir}"
    cat >"${consumer_dir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.23)
project(singleconfig_consumer LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
find_package(math_lib CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE Math::math_lib Utils::string_utils)
CMAKE
    cat >"${consumer_dir}/main.cpp" <<CPP
#include <iostream>
int main(){ std::cout << "ok-${cfg_lc}\\n"; return 0; }
CPP

    cmake -S "${consumer_dir}" -B "${consumer_dir}/build" -G Ninja -DCMAKE_BUILD_TYPE="${cfg}" \
      -DCMAKE_PREFIX_PATH="${prefixes}"

    log_file="${consumer_dir}/build.log"
    (cmake --build "${consumer_dir}/build" -v | tee "${log_file}")

    if [[ "${cfg}" == "Release" ]]; then
      grep -E "[\\\\/](release)[\\\\/](lib|lib64)" "${log_file}"
      if grep -E "[\\\\/](debug)[\\\\/](lib|lib64)" "${log_file}"; then
        ci_die "Found debug libs in Release link (single-config)!"
      fi
    else
      grep -E "[\\\\/](debug)[\\\\/](lib|lib64)" "${log_file}"
      if grep -E "[\\\\/](release)[\\\\/](lib|lib64)" "${log_file}"; then
        ci_die "Found release libs in Debug link (single-config)!"
      fi
    fi
  done
}

run_consume_fhs_combined_suite() {
  ci_python_bin="$(ci_python)" || ci_die "Missing required command: python (or python3)"
  ci_log "==> Build+install basic-* (FHS, combined configs)"
  for ex in basic-static basic-shared; do
    (cd "${ci_root}/examples/${ex}" && \
      rm -rf build-rel build-dbg build/install && \
      cmake -S . -B build-rel -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./build/install -DTIP_INSTALL_LAYOUT=fhs && \
      cmake --build build-rel && \
      cmake --install build-rel && \
      cmake -S . -B build-dbg -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=./build/install -DTIP_INSTALL_LAYOUT=fhs && \
      cmake --build build-dbg && \
      cmake --install build-dbg)
  done

  prefix_math="$("${ci_python_bin}" -c 'import os; print(os.path.abspath(os.path.join("examples","basic-static","build","install")))' )"
  prefix_utils="$("${ci_python_bin}" -c 'import os; print(os.path.abspath(os.path.join("examples","basic-shared","build","install")))' )"
  prefixes="$(ci_join_by ';' "$(ci_path_for_cmake "${prefix_math}")" "$(ci_path_for_cmake "${prefix_utils}")")"

  for cfg in Release Debug; do
    cfg_lc="$(ci_lower "${cfg}")"
    consumer_dir="${ci_root}/build/ci-consumer/fhs/${cfg_lc}"
    rm -rf "${consumer_dir}"
    mkdir -p "${consumer_dir}"
    cat >"${consumer_dir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.23)
project(fhs_consumer LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
find_package(math_lib CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE Math::math_lib Utils::string_utils)
CMAKE
    cat >"${consumer_dir}/main.cpp" <<CPP
#include <iostream>
int main(){ std::cout << "ok-fhs-${cfg_lc}\\n"; return 0; }
CPP

    cmake -S "${consumer_dir}" -B "${consumer_dir}/build" -G Ninja -DCMAKE_BUILD_TYPE="${cfg}" \
      -DCMAKE_PREFIX_PATH="${prefixes}"

    log_file="${consumer_dir}/build.log"
    (cmake --build "${consumer_dir}/build" -v | tee "${log_file}")

    if [[ "${cfg}" == "Release" ]]; then
      if grep -E "math_libd" "${log_file}"; then
        ci_die "Found debug math_lib in Release link (FHS)!"
      fi
      if grep -E "string_utilsd" "${log_file}"; then
        ci_die "Found debug string_utils in Release link (FHS)!"
      fi
    else
      grep -E "math_libd" "${log_file}"
      grep -E "string_utilsd" "${log_file}"
    fi

    if ci_is_windows; then
      "${consumer_dir}/build/consumer.exe"
    else
      "${consumer_dir}/build/consumer"
    fi
  done
}

case "${suite}" in
  single) run_single_suite ;;
  multi) run_multi_suite ;;
  consume-multi-config) run_consume_multi_config_suite ;;
  consume-single-config) run_consume_single_config_suite ;;
  consume-fhs-combined) run_consume_fhs_combined_suite ;;
  *)
    usage >&2
    ci_die "Unknown suite: ${suite}"
    ;;
esac
