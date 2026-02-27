#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ci/run.sh package-managers [options]

Suites:
  conan     Build/test package with Conan recipe + test_package
  vcpkg     Install overlay port and run downstream CMake smoke test
  all       Run both suites (default)

Options:
  --suite <name>          Suite to run (default: all)
  --work-dir <dir>        Scratch directory for smoke projects (default: build/ci-package-managers)
  --vcpkg-exe <path>      Path to vcpkg executable (default: auto-detect from PATH or VCPKG_ROOT)
  --triplet <name>        vcpkg triplet override (default: x64-linux/x64-osx/x64-windows by OS)
  -h, --help              Show help

Examples:
  ci/run.sh package-managers --suite all
  ci/run.sh package-managers --suite vcpkg --vcpkg-exe /path/to/vcpkg
EOF
}

suite="all"
work_dir="${ci_root}/build/ci-package-managers"
vcpkg_exe=""
triplet=""

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
    --work-dir)
      work_dir="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --vcpkg-exe)
      vcpkg_exe="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --triplet)
      triplet="${2:?}"
      shift 2
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

default_triplet_for_os() {
  if ci_is_windows; then
    printf '%s\n' "x64-windows"
  elif ci_is_macos; then
    printf '%s\n' "x64-osx"
  else
    printf '%s\n' "x64-linux"
  fi
}

detect_vcpkg_exe() {
  if [[ -n "${vcpkg_exe}" ]]; then
    printf '%s\n' "${vcpkg_exe}"
    return 0
  fi

  if ci_has_cmd vcpkg; then
    command -v vcpkg
    return 0
  fi

  if [[ -n "${VCPKG_ROOT:-}" ]]; then
    if [[ -x "${VCPKG_ROOT}/vcpkg" ]]; then
      printf '%s\n' "${VCPKG_ROOT}/vcpkg"
      return 0
    fi
    if [[ -f "${VCPKG_ROOT}/vcpkg.exe" ]]; then
      printf '%s\n' "${VCPKG_ROOT}/vcpkg.exe"
      return 0
    fi
  fi

  ci_die "Unable to find vcpkg executable. Use --vcpkg-exe <path> or set VCPKG_ROOT."
}

resolve_vcpkg_root() {
  local vcpkg_bin="$1"

  if [[ -n "${VCPKG_ROOT:-}" ]]; then
    local env_root
    env_root="$(ci_abs_path "${VCPKG_ROOT}")"
    if [[ -f "${env_root}/scripts/buildsystems/vcpkg.cmake" ]]; then
      printf '%s\n' "${env_root}"
      return 0
    fi
    ci_warn "VCPKG_ROOT is set but toolchain file was not found at ${env_root}/scripts/buildsystems/vcpkg.cmake; falling back to executable path"
  fi

  local resolved_bin="${vcpkg_bin}"
  if ci_has_cmd realpath; then
    local realpath_out=""
    realpath_out="$(realpath "${vcpkg_bin}" 2>/dev/null || true)"
    if [[ -n "${realpath_out}" ]]; then
      resolved_bin="${realpath_out}"
    fi
  else
    local py_bin=""
    if py_bin="$(ci_python 2>/dev/null)"; then
      local py_resolved=""
      py_resolved="$("${py_bin}" -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${vcpkg_bin}" 2>/dev/null || true)"
      if [[ -n "${py_resolved}" ]]; then
        resolved_bin="${py_resolved}"
      fi
    elif ci_has_cmd readlink; then
      local link_out=""
      link_out="$(readlink "${vcpkg_bin}" 2>/dev/null || true)"
      if [[ -n "${link_out}" ]]; then
        if [[ "${link_out}" == /* ]]; then
          resolved_bin="${link_out}"
        else
          resolved_bin="$(cd "$(dirname "${vcpkg_bin}")" && cd "$(dirname "${link_out}")" && pwd)/$(basename "${link_out}")"
        fi
      fi
    fi
  fi

  local candidate_root=""
  candidate_root="$(cd "$(dirname "${resolved_bin}")" && pwd)"
  if [[ -f "${candidate_root}/scripts/buildsystems/vcpkg.cmake" ]]; then
    printf '%s\n' "${candidate_root}"
    return 0
  fi

  candidate_root="$(cd "${candidate_root}/.." && pwd)"
  if [[ -f "${candidate_root}/scripts/buildsystems/vcpkg.cmake" ]]; then
    printf '%s\n' "${candidate_root}"
    return 0
  fi

  return 1
}

run_conan_suite() {
  local conan_bin=""
  if ci_has_cmd conan; then
    conan_bin="$(command -v conan)"
  else
    local py_bin="" scripts_dir=""
    if py_bin="$(ci_python 2>/dev/null)"; then
      scripts_dir="$(
        "${py_bin}" - <<'PY'
import pathlib
import sysconfig

scripts = sysconfig.get_path("scripts") or ""
print(pathlib.Path(scripts).as_posix() if scripts else "")
PY
      )"

      if [[ -n "${scripts_dir}" ]]; then
        if [[ -x "${scripts_dir}/conan" ]]; then
          conan_bin="${scripts_dir}/conan"
        elif [[ -f "${scripts_dir}/conan.exe" ]]; then
          conan_bin="${scripts_dir}/conan.exe"
        fi
      fi
    fi
  fi

  if [[ -z "${conan_bin}" ]]; then
    ci_die "Conan not found. Install Conan and ensure the `conan` executable is available."
  fi

  ci_log "==> Conan profile detect"
  "${conan_bin}" --version
  "${conan_bin}" profile detect --force

  ci_log "==> Conan create (recipe + test_package)"
  (
    cd "${ci_root}"
    "${conan_bin}" create . --build=missing --no-remote
  )
}

run_vcpkg_suite() {
  local vcpkg_bin vcpkg_root toolchain_file smoke_dir
  vcpkg_bin="$(detect_vcpkg_exe)"
  if ! vcpkg_root="$(resolve_vcpkg_root "${vcpkg_bin}")"; then
    ci_die "Unable to determine vcpkg root from '${vcpkg_bin}'. Set VCPKG_ROOT to your vcpkg installation root."
  fi
  toolchain_file="${vcpkg_root}/scripts/buildsystems/vcpkg.cmake"

  if [[ ! -f "${toolchain_file}" ]]; then
    ci_die "vcpkg toolchain file not found: ${toolchain_file}"
  fi

  local resolved_triplet
  if [[ -n "${triplet}" ]]; then
    resolved_triplet="${triplet}"
  else
    resolved_triplet="$(default_triplet_for_os)"
  fi

  ci_log "==> vcpkg install overlay port (${resolved_triplet})"
  "${vcpkg_bin}" install target-install-package \
    "--triplet=${resolved_triplet}" \
    "--overlay-ports=${ci_root}/packaging/vcpkg/ports"

  smoke_dir="${work_dir}/vcpkg-smoke"
  rm -rf "${smoke_dir}"
  mkdir -p "${smoke_dir}"

  cat >"${smoke_dir}/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.25)
project(vcpkg_smoke LANGUAGES CXX)

find_package(target_install_package CONFIG REQUIRED)

add_executable(vcpkg_smoke main.cpp)
target_compile_features(vcpkg_smoke PRIVATE cxx_std_17)
target_install_package(vcpkg_smoke NAMESPACE VcpkgSmoke:: VERSION 0.0.1)
CMAKE

  cat >"${smoke_dir}/main.cpp" <<'CPP'
#include <iostream>

int main() {
  std::cout << "vcpkg smoke test ok\n";
  return 0;
}
CPP

  ci_log "==> vcpkg consumer configure/build"
  cmake --log-level=DEBUG -S "${smoke_dir}" -B "${smoke_dir}/build" \
    -DCMAKE_TOOLCHAIN_FILE="$(ci_path_for_cmake "${toolchain_file}")" \
    -DVCPKG_TARGET_TRIPLET="${resolved_triplet}"
  cmake --build "${smoke_dir}/build"
}

case "${suite}" in
  conan)
    run_conan_suite
    ;;
  vcpkg)
    run_vcpkg_suite
    ;;
  all)
    run_conan_suite
    run_vcpkg_suite
    ;;
  *)
    usage >&2
    ci_die "Unknown suite: ${suite}"
    ;;
esac
