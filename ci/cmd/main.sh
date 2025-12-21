#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

ci_setup_ccache "${ci_root}"

usage() {
  cat <<'EOF'
Usage: ci/run.sh main [options]

Configures/builds/tests/installs the root project using `CMakePresets.json`.

Options:
  --preset <name>         Configure preset (default: ci-release)
  --build-type <type>     Convenience: selects preset `ci-<lower(type)>`
  --compiler <name>       Compiler family (gcc/clang/cl), sets --cc/--cxx
  --cc <path>             C compiler for configure
  --cxx <path>            C++ compiler for configure
  --fmt-prefix <dir>      Prefix that contains fmt (optional; default: ./build/ci-deps/fmt-install if present)
  --cmake-arg <arg>       Extra arg forwarded to `cmake --preset ...` (repeatable)
  -h, --help              Show help

Examples:
  ci/run.sh main --preset ci-release
  ci/run.sh main --build-type Release --compiler clang
EOF
}

preset=""
build_type=""
compiler_choice=""
cc=""
cxx=""
fmt_prefix=""
cmake_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
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
    --cmake-arg)
      cmake_args+=("${2:?}")
      shift 2
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

if [[ -z "${fmt_prefix}" ]]; then
  if [[ -d "${ci_root}/build/ci-deps/fmt-install" ]]; then
    fmt_prefix="${ci_root}/build/ci-deps/fmt-install"
  elif [[ -d "${ci_root}/fmt-install" ]]; then
    fmt_prefix="${ci_root}/fmt-install"
  fi
fi

configure_args=()
if [[ -n "${cc}" ]]; then
  configure_args+=("-DCMAKE_C_COMPILER=${cc}")
fi
if [[ -n "${cxx}" ]]; then
  configure_args+=("-DCMAKE_CXX_COMPILER=${cxx}")
fi
if [[ -n "${fmt_prefix}" ]]; then
  configure_args+=("-DCMAKE_PREFIX_PATH=$(ci_path_for_cmake "${fmt_prefix}")")
fi
if ci_is_macos && (ci_is_homebrew_llvm_compiler "${cc}" || ci_is_homebrew_llvm_compiler "${cxx}"); then
  if sdkroot="$(ci_macos_sdkroot)"; then
    export SDKROOT="${sdkroot}"
    configure_args+=("-DCMAKE_OSX_SYSROOT=$(ci_path_for_cmake "${sdkroot}")")
    ci_log "macOS SDKROOT: ${sdkroot}"
  else
    ci_warn "xcrun not found; Homebrew LLVM may not find the macOS SDK"
  fi
fi
configure_args+=("-DPROJECT_LOG_COLORS=ON")
configure_args+=("${cmake_args[@]}")

ci_log "==> Configure (${preset})"
cmake --log-level=DEBUG --preset "${preset}" "${configure_args[@]}"

ci_log "==> Build (${preset})"
cmake --build --preset "${preset}"

ci_log "==> Test (${preset})"
ctest --preset "${preset}"

build_dir="$(ci_build_dir_from_preset "${ci_root}" "${preset}")"
install_dir="$(ci_install_dir_from_preset "${ci_root}" "${preset}")"
if [[ -z "${build_dir}" || -z "${install_dir}" ]]; then
  ci_die "Unable to infer build/install dirs for preset '${preset}' (use a ci-* or dev preset)"
fi

ci_log "==> Install (${preset})"
cmake --install "${build_dir}"

ci_log "==> Verify install layout"
cfg_dir="${install_dir}/share/cmake/target_install_package"
if [[ -f "${cfg_dir}/target_install_package.cmake" ]]; then
  ci_log "✓ ${cfg_dir}/target_install_package.cmake"
else
  ci_die "Missing installed file: ${cfg_dir}/target_install_package.cmake"
fi

ci_log "==> Component install smoke test"
cmake --install "${build_dir}" \
  --component CMakeUtilities_Development \
  --prefix "${install_dir}-components"
if [[ -f "${install_dir}-components/share/cmake/target_install_package/target_install_package.cmake" ]]; then
  ci_log "✓ Component install OK"
else
  ci_die "Component install missing expected file"
fi

if ! ci_is_windows; then
  bt="$(ci_build_type_from_preset "${preset}")"
  if [[ -z "${bt}" ]]; then
    bt="${build_type:-Release}"
  fi

  ci_log "==> Variant configure/build/install (Unix)"
  cmake --log-level=DEBUG -S "${ci_root}" -B "${build_dir}-variant" -G Ninja \
    ${cc:+-DCMAKE_C_COMPILER=${cc}} \
    ${cxx:+-DCMAKE_CXX_COMPILER=${cxx}} \
    -DCMAKE_BUILD_TYPE="${bt}" \
    -DCMAKE_INSTALL_PREFIX="${install_dir}-variant" \
    -DPROJECT_LOG_COLORS=ON \
    ${fmt_prefix:+-DCMAKE_PREFIX_PATH=$(ci_path_for_cmake "${fmt_prefix}")} \
    -Dtarget_install_package_BUILD_TESTS=ON
  cmake --build "${build_dir}-variant"
  cmake --install "${build_dir}-variant"
fi

ci_log "==> Validate CMake minimum version (>= 3.25.0)"
cmake_version="$(cmake --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
required_version="3.25.0"
if [[ -z "${cmake_version}" ]]; then
  ci_warn "Unable to parse cmake version"
elif [[ "$(printf '%s\n' "${required_version}" "${cmake_version}" | sort -V | head -n1)" == "${required_version}" ]]; then
  ci_log "✓ cmake ${cmake_version}"
else
  ci_die "CMake ${cmake_version} < ${required_version}"
fi
