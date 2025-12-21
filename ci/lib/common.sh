#!/usr/bin/env bash
set -euo pipefail

ci_log() {
  printf '%s\n' "$*"
}

ci_warn() {
  printf 'warning: %s\n' "$*" >&2
}

ci_die() {
  printf 'error: %b\n' "$*" >&2
  exit 1
}

ci_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ci_python() {
  if ci_has_cmd python3; then
    printf '%s\n' python3
    return 0
  fi
  if ci_has_cmd python; then
    printf '%s\n' python
    return 0
  fi
  return 1
}

ci_require_cmd() {
  local cmd="$1"
  if ! ci_has_cmd "${cmd}"; then
    ci_die "Missing required command: ${cmd}"
  fi
}

ci_uname_s() {
  uname -s 2>/dev/null || echo unknown
}

ci_is_windows() {
  case "$(ci_uname_s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

ci_is_macos() {
  [[ "$(ci_uname_s)" == "Darwin" ]]
}

ci_is_linux() {
  [[ "$(ci_uname_s)" == "Linux" ]]
}

ci_macos_sdkroot() {
  if ! ci_is_macos; then
    return 1
  fi
  if ! ci_has_cmd xcrun; then
    return 1
  fi
  xcrun --sdk macosx --show-sdk-path 2>/dev/null
}

ci_is_homebrew_llvm_compiler() {
  local compiler="${1:-}"
  case "${compiler}" in
    */opt/homebrew/opt/llvm/*|*/usr/local/opt/llvm/*) return 0 ;;
    *) return 1 ;;
  esac
}

ci_normalize_ws_path() {
  # Normalize a GitHub-provided workspace path for bash usage (Windows runners provide backslashes).
  local p="$1"
  if ci_is_windows && ci_has_cmd cygpath; then
    cygpath -u "${p}"
    return 0
  fi
  printf '%s\n' "${p//\\//}"
}

ci_abs_path() {
  local p="$1"
  local ci_python_bin=""
  if ci_python_bin="$(ci_python 2>/dev/null)"; then
    "${ci_python_bin}" -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "${p}"
    return 0
  fi
  # Fallback: best-effort.
  local dir base
  dir="$(cd "$(dirname "${p}")" && pwd)"
  base="$(basename "${p}")"
  printf '%s/%s\n' "${dir}" "${base}"
}

ci_path_for_cmake() {
  # Return an absolute path that CMake accepts (forward slashes on Windows).
  local p
  p="$(ci_abs_path "$1")"
  if ci_is_windows && ci_has_cmd cygpath; then
    cygpath -m "${p}"
    return 0
  fi
  printf '%s\n' "${p}"
}

ci_join_by() {
  local sep="$1"
  shift
  local out="" item
  for item in "$@"; do
    if [[ -z "${out}" ]]; then
      out="${item}"
    else
      out="${out}${sep}${item}"
    fi
  done
  printf '%s\n' "${out}"
}

ci_sudo() {
  if ci_is_windows; then
    "$@"
    return $?
  fi

  if [[ "$(id -u)" == "0" ]]; then
    "$@"
    return $?
  fi

  if ci_has_cmd sudo; then
    sudo "$@"
    return $?
  fi

  ci_die "Command requires elevated privileges, but sudo is unavailable: $*"
}

ci_add_path() {
  local p="$1"
  if [[ -z "${p}" ]]; then
    return 0
  fi

  if [[ -n "${GITHUB_PATH:-}" ]]; then
    printf '%s\n' "${p}" >>"${GITHUB_PATH}"
  fi

  export PATH="${p}:${PATH}"
}

ci_setup_ccache() {
  local root="${1:?}"
  if ci_has_cmd ccache; then
    export CCACHE_DIR="${CCACHE_DIR:-${root}/build/ccache}"
    export CCACHE_TEMPDIR="${CCACHE_TEMPDIR:-${CCACHE_DIR}/tmp}"
    mkdir -p "${CCACHE_TEMPDIR}"
  fi
}

ci_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

ci_preset_from_build_type() {
  local build_type="${1:-}"
  if [[ -z "${build_type}" ]]; then
    printf '%s\n' "ci-release"
    return 0
  fi
  printf 'ci-%s\n' "$(ci_lower "${build_type}")"
}

ci_build_type_from_preset() {
  local preset="$1"
  case "${preset}" in
    ci-debug) printf '%s\n' "Debug" ;;
    ci-release) printf '%s\n' "Release" ;;
    ci-minsizerel) printf '%s\n' "MinSizeRel" ;;
    ci-relwithdebinfo) printf '%s\n' "RelWithDebInfo" ;;
    dev) printf '%s\n' "RelWithDebInfo" ;;
    *) printf '%s\n' "" ;;
  esac
}

ci_build_dir_from_preset() {
  local root="$1"
  local preset="$2"
  case "${preset}" in
    dev) printf '%s\n' "${root}/build/dev" ;;
    ci-*) printf '%s\n' "${root}/build/ci/${preset#ci-}" ;;
    *) printf '%s\n' "" ;;
  esac
}

ci_install_dir_from_preset() {
  local root="$1"
  local preset="$2"
  local build_dir
  build_dir="$(ci_build_dir_from_preset "${root}" "${preset}")"
  if [[ -z "${build_dir}" ]]; then
    printf '%s\n' ""
    return 0
  fi
  printf '%s\n' "${build_dir}/install"
}

ci_compilers_from_choice() {
  # Prints "cc;cxx" for a compiler choice like gcc/clang/cl/gcc-14/clang++ path.
  local choice="${1:-}"
  case "${choice}" in
    ""|gcc) printf '%s\n' "gcc;g++" ;;
    clang) printf '%s\n' "clang;clang++" ;;
    cl) printf '%s\n' "cl;cl" ;;
    gcc-*) printf '%s\n' "${choice};g++-${choice#gcc-}" ;;
    g++-*) printf '%s\n' "gcc-${choice#g++-};${choice}" ;;
    *) printf '%s\n' "${choice};${choice}++" ;;
  esac
}
