#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ci/run.sh bootstrap [options]

Options:
  --ninja                 Ensure Ninja is installed
  --fmt                   Build+install fmt to a prefix
  --fmt-prefix <dir>      fmt install prefix (default: ./build/ci-deps/fmt-install)
  --fmt-ref <git-ref>     fmt git ref/sha (default: pinned commit)
  --build-type <type>     Build type for fmt (default: Release)
  --compiler <name>       Compiler family (gcc/clang/cl), sets --cc/--cxx
  --cc <path>             C compiler for fmt build
  --cxx <path>            C++ compiler for fmt build
  --packaging-tools       Install packaging tools (Linux: rpm, dpkg-dev, file)
  --gpg                   Install GPG (Linux/macOS)
  -h, --help              Show help
EOF
}

ensure_ninja=false
ensure_fmt=false
ensure_packaging_tools=false
ensure_gpg=false

fmt_prefix="${ci_root}/build/ci-deps/fmt-install"
fmt_ref="53d006abfdc0653f7d3e4e180e694fcb720524b5"
build_type="Release"

cc=""
cxx=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --ninja)
      ensure_ninja=true
      shift
      ;;
    --fmt)
      ensure_fmt=true
      shift
      ;;
    --fmt-prefix)
      fmt_prefix="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --fmt-ref)
      fmt_ref="${2:?}"
      shift 2
      ;;
    --build-type)
      build_type="${2:?}"
      shift 2
      ;;
    --compiler)
      compiler_choice="${2:?}"
      IFS=';' read -r cc cxx <<<"$(ci_compilers_from_choice "${compiler_choice}")"
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
    --packaging-tools)
      ensure_packaging_tools=true
      shift
      ;;
    --gpg)
      ensure_gpg=true
      shift
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

ci_require_cmd cmake

if [[ "${ensure_ninja}" == "true" ]]; then
  if ci_has_cmd ninja; then
    ci_log "ninja: $(ninja --version)"
  else
    ci_log "Installing Ninja..."
    if ci_is_linux; then
      ci_sudo apt-get update
      ci_sudo apt-get install -y ninja-build
    elif ci_is_macos; then
      ci_require_cmd brew
      brew install ninja
    elif ci_is_windows; then
      ci_require_cmd choco
      choco install ninja -y
      ci_add_path "C:/ProgramData/chocolatey/lib/ninja/tools"
    else
      ci_die "Unsupported OS for Ninja installation"
    fi
    ci_require_cmd ninja
    ci_log "ninja: $(ninja --version)"
  fi
fi

if [[ "${ensure_packaging_tools}" == "true" ]]; then
  if ci_is_linux; then
    ci_log "Installing Linux packaging tools..."
    ci_sudo apt-get update
    ci_sudo apt-get install -y build-essential cmake ninja-build rpm dpkg-dev file
  else
    ci_warn "packaging-tools: currently only supported on Linux (skipping)"
  fi
fi

if [[ "${ensure_gpg}" == "true" ]]; then
  if ci_has_cmd gpg; then
    gpg --version | head -n 3
  else
    if ci_is_linux; then
      ci_sudo apt-get update
      ci_sudo apt-get install -y gnupg2
    elif ci_is_macos; then
      ci_require_cmd brew
      brew install gnupg
    else
      ci_warn "gpg: auto-install unsupported on this OS (skipping)"
    fi
  fi
fi

if [[ "${ensure_fmt}" == "true" ]]; then
  if [[ -z "${cc}" || -z "${cxx}" ]]; then
    IFS=';' read -r cc cxx <<<"$(ci_compilers_from_choice "${CC:-gcc}")"
  fi

  if [[ -f "${fmt_prefix}/lib/cmake/fmt/fmtConfig.cmake" || -f "${fmt_prefix}/lib/cmake/fmt/fmt-config.cmake" ]]; then
    ci_log "fmt already installed under: ${fmt_prefix}"
    exit 0
  fi

  cc_base="$(basename "${cc}")"
  compiler_id_candidates=()
  case "${cc_base}" in
    clang*|*clang*)
      compiler_id_candidates=(Clang GNU MSVC)
      ;;
    cl|cl.exe)
      compiler_id_candidates=(MSVC GNU Clang)
      ;;
    *)
      compiler_id_candidates=(GNU Clang MSVC)
      ;;
  esac

  has_system_fmt=false
  probe_dir="${ci_root}/build/ci-deps/find-package-probe"
  mkdir -p "${probe_dir}"
  for compiler_id in "${compiler_id_candidates[@]}"; do
    if (cd "${probe_dir}" && cmake --find-package -DNAME=fmt -DLANGUAGE=CXX -DMODE=EXIST -DCOMPILER_ID="${compiler_id}" >/dev/null 2>&1); then
      has_system_fmt=true
      break
    fi
  done
  if [[ "${has_system_fmt}" == "true" ]]; then
    ci_log "fmt found via system CMake packages; skipping fmt build"
    exit 0
  fi

  ci_require_cmd git
  ci_require_cmd ninja

  src_dir="${ci_root}/build/ci-deps/fmt-src"
  build_dir="${ci_root}/build/ci-deps/fmt-build"
  ci_log "Installing fmt (${fmt_ref}) to ${fmt_prefix}"

  rm -rf "${src_dir}" "${build_dir}"
  mkdir -p "${src_dir}" "${build_dir}" "${fmt_prefix}"

  if ! git clone https://github.com/fmtlib/fmt.git "${src_dir}"; then
    ci_warn "Unable to clone fmt (network unavailable?)."
    ci_die "fmt not available via system packages and clone failed"
  fi
  if ! git -C "${src_dir}" checkout "${fmt_ref}"; then
    ci_warn "Unable to checkout fmt ref: ${fmt_ref}"
    ci_die "fmt checkout failed"
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

  cmake -S "${src_dir}" -B "${build_dir}" -G Ninja \
    -DCMAKE_C_COMPILER="${cc}" \
    -DCMAKE_CXX_COMPILER="${cxx}" \
    "${osx_sysroot_args[@]}" \
    -DCMAKE_BUILD_TYPE="${build_type}" \
    -DCMAKE_INSTALL_PREFIX="${fmt_prefix}" \
    -DFMT_DOC=OFF \
    -DFMT_TEST=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

  cmake --build "${build_dir}"
  cmake --install "${build_dir}"
  ci_log "fmt installed: ${fmt_prefix}"
fi
