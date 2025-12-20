#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

ci_setup_ccache "${ci_root}"

usage() {
  cat <<'EOF'
Usage: ci/run.sh packaging-tests [options]

Runs `tests/packaging/build-packages.sh` and `tests/packaging/test-packages.sh`.

Options:
  --mode <name>           all (default) | arch-detection
  --skip-container-tests  Skip Docker/Podman package installation tests
  -h, --help              Show help
EOF
}

mode="all"
skip_container_tests=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --mode)
      mode="${2:?}"
      shift 2
      ;;
    --skip-container-tests)
      skip_container_tests=true
      shift
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

packaging_dir="${ci_root}/tests/packaging"

run_arch_detection() {
  mkdir -p "${ci_root}/build/ci-deps"
  script_path="${ci_root}/build/ci-deps/test-arch-detection.cmake"
  cat >"${script_path}" <<'CMAKE'
cmake_minimum_required(VERSION 3.16)

set(TEST_ARCHS "x86_64;i686;aarch64;armv7l")

foreach(ARCH ${TEST_ARCHS})
  message(STATUS "Testing architecture: ${ARCH}")
  set(CMAKE_SYSTEM_PROCESSOR ${ARCH})

  set(_TIP_ARCH_X64_PATTERNS "x86_64|AMD64|amd64")
  set(_TIP_ARCH_X86_PATTERNS "i[3-6]86|x86")
  set(_TIP_ARCH_ARM64_PATTERNS "aarch64|arm64|ARM64")
  set(_TIP_ARCH_ARM32_PATTERNS "armv7.*|arm")

  if(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_X64_PATTERNS})
    set(_TIP_CANONICAL_ARCH "x64")
    set(DEB_ARCH "amd64")
    set(RPM_ARCH "x86_64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_X86_PATTERNS})
    set(_TIP_CANONICAL_ARCH "x86")
    set(DEB_ARCH "i386")
    set(RPM_ARCH "i686")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_ARM64_PATTERNS})
    set(_TIP_CANONICAL_ARCH "arm64")
    set(DEB_ARCH "arm64")
    set(RPM_ARCH "aarch64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_ARM32_PATTERNS})
    set(_TIP_CANONICAL_ARCH "arm32")
    set(DEB_ARCH "armhf")
    set(RPM_ARCH "armv7hl")
  else()
    set(_TIP_CANONICAL_ARCH "unknown")
    set(DEB_ARCH "unknown")
    set(RPM_ARCH "unknown")
  endif()

  message(STATUS "  Canonical: ${_TIP_CANONICAL_ARCH}")
  message(STATUS "  DEB arch: ${DEB_ARCH}")
  message(STATUS "  RPM arch: ${RPM_ARCH}")
  message(STATUS "")
endforeach()
CMAKE
  cmake -P "${script_path}"
}

if [[ "${mode}" == "arch-detection" ]]; then
  ci_log "==> Multi-arch detection smoke test"
  run_arch_detection
  exit 0
fi

ci_log "==> Build packages"
(cd "${packaging_dir}" && chmod +x build-packages.sh && ./build-packages.sh)

ci_log "==> List generated packages"
(cd "${packaging_dir}" && ls -la packages/ && (ls -la packages/*.deb packages/*.rpm packages/*.tar.gz 2>/dev/null || true))

ci_log "==> Verify DEB architecture field"
if ci_has_cmd dpkg-deb; then
  (cd "${packaging_dir}" && \
    for deb in packages/*.deb; do
      [[ -f "${deb}" ]] || continue
      ci_log "Checking ${deb}..."
      arch="$(dpkg-deb --field "${deb}" Architecture)"
      ci_log "Architecture: ${arch}"
      if [[ -z "${arch}" || "${arch}" == " " ]]; then
        ci_die "Empty architecture field in ${deb}"
      fi
      case "${arch}" in
        amd64|i386|arm64|armhf|all) ci_log "✓ Valid architecture: ${arch}" ;;
        *) ci_warn "Unexpected DEB architecture: ${arch}" ;;
      esac
    done)
else
  ci_warn "dpkg-deb not available; skipping DEB architecture checks"
fi

ci_log "==> Verify RPM architecture field"
if ci_has_cmd rpm; then
  (cd "${packaging_dir}" && \
    for rpm_pkg in packages/*.rpm; do
      [[ -f "${rpm_pkg}" ]] || continue
      ci_log "Checking ${rpm_pkg}..."
      arch="$(rpm -qp --qf "%{ARCH}\n" "${rpm_pkg}")"
      ci_log "Architecture: ${arch}"
      if [[ -z "${arch}" || "${arch}" == " " ]]; then
        ci_die "Empty architecture field in ${rpm_pkg}"
      fi
      case "${arch}" in
        x86_64|i686|aarch64|armv7hl|noarch) ci_log "✓ Valid architecture: ${arch}" ;;
        *) ci_warn "Unexpected RPM architecture: ${arch}" ;;
      esac
    done)
else
  ci_warn "rpm not available; skipping RPM architecture checks"
fi

ci_log "==> Multi-arch detection smoke test"
run_arch_detection

if [[ "${skip_container_tests}" == "true" ]]; then
  ci_warn "Skipping container installation tests (--skip-container-tests)"
  exit 0
fi

if ! ci_has_cmd docker && ! ci_has_cmd podman; then
  ci_warn "Docker/Podman not available; skipping container installation tests"
  exit 0
fi

ci_log "==> Run package installation tests (containers)"
(cd "${packaging_dir}" && \
  chmod +x test-packages.sh && \
  has_deb=false && has_rpm=false && \
  ls packages/*.deb >/dev/null 2>&1 && has_deb=true || true && \
  ls packages/*.rpm >/dev/null 2>&1 && has_rpm=true || true && \
  if [[ "${has_deb}" == "true" ]]; then
    ./test-packages.sh ubuntu
  else
    ci_warn "No .deb packages found; skipping Ubuntu container test"
  fi && \
  if [[ "${has_rpm}" == "true" ]]; then
    ./test-packages.sh fedora
  else
    ci_warn "No .rpm packages found; skipping Fedora container test"
  fi)
