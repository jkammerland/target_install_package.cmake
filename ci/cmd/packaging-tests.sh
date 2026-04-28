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
packaging_work_dir="${ci_root}/build/packaging"
packaging_build_dir="${packaging_work_dir}/build"
packaging_packages_dir="${packaging_work_dir}/packages"
expected_package_version="1.2.0"
expected_package_summary="CPack integration example with target_install_package"
expected_package_license="MIT"

run_arch_detection() {
  mkdir -p "${ci_root}/build/ci-deps"
  script_path="${ci_root}/build/ci-deps/test-arch-detection.cmake"
  cat >"${script_path}" <<CMAKE
cmake_minimum_required(VERSION 3.25)

set(CMAKE_INSTALL_LIBDIR lib)
include("${ci_root}/cmake/load_target_install_package.cmake")

set(TEST_CASES
    "x86_64|x64|amd64|x86_64"
    "i686|x86|i386|i686"
    "aarch64|arm64|arm64|aarch64"
    "armv7l|arm32|armhf|armv7hl")

foreach(test_case \${TEST_CASES})
  string(REPLACE "|" ";" fields "\${test_case}")
  list(GET fields 0 ARCH)
  list(GET fields 1 EXPECTED_CANONICAL)
  list(GET fields 2 EXPECTED_DEB)
  list(GET fields 3 EXPECTED_RPM)

  _tip_detect_package_architecture("\${ARCH}" ACTUAL_CANONICAL ACTUAL_DEB ACTUAL_RPM ACTUAL_KNOWN)

  message(STATUS "Testing architecture: \${ARCH}")
  message(STATUS "  Canonical: \${ACTUAL_CANONICAL}")
  message(STATUS "  DEB arch: \${ACTUAL_DEB}")
  message(STATUS "  RPM arch: \${ACTUAL_RPM}")

  if(NOT ACTUAL_KNOWN)
    message(FATAL_ERROR "Architecture should be recognized but was not: \${ARCH}")
  endif()
  if(NOT ACTUAL_CANONICAL STREQUAL EXPECTED_CANONICAL)
    message(FATAL_ERROR "Canonical architecture mismatch for \${ARCH}: expected \${EXPECTED_CANONICAL}, got \${ACTUAL_CANONICAL}")
  endif()
  if(NOT ACTUAL_DEB STREQUAL EXPECTED_DEB)
    message(FATAL_ERROR "DEB architecture mismatch for \${ARCH}: expected \${EXPECTED_DEB}, got \${ACTUAL_DEB}")
  endif()
  if(NOT ACTUAL_RPM STREQUAL EXPECTED_RPM)
    message(FATAL_ERROR "RPM architecture mismatch for \${ARCH}: expected \${EXPECTED_RPM}, got \${ACTUAL_RPM}")
  endif()
  message(STATUS "")
endforeach()
CMAKE
  cmake -Wno-dev -P "${script_path}"
}

if [[ "${mode}" == "arch-detection" ]]; then
  ci_log "==> Multi-arch detection smoke test"
  run_arch_detection
  exit 0
fi

ci_log "==> Build packages"
bash "${packaging_dir}/build-packages.sh" --build-dir "${packaging_build_dir}" --packages-dir "${packaging_packages_dir}"

ci_log "==> List generated packages"
ls -la "${packaging_packages_dir}" && (ls -la "${packaging_packages_dir}"/*.deb "${packaging_packages_dir}"/*.rpm "${packaging_packages_dir}"/*.tar.gz 2>/dev/null || true)

ci_log "==> Verify DEB architecture field"
if ci_has_cmd dpkg-deb; then
  ( \
    for deb in "${packaging_packages_dir}"/*.deb; do
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

      version="$(dpkg-deb --field "${deb}" Version)"
      ci_log "Version: ${version}"
      if [[ "${version}" != "${expected_package_version}" ]]; then
        ci_die "Unexpected DEB package version in ${deb}: ${version}"
      fi
    done)
else
  ci_warn "dpkg-deb not available; skipping DEB architecture checks"
fi

ci_log "==> Verify RPM architecture field"
if ci_has_cmd rpm; then
  ( \
    for rpm_pkg in "${packaging_packages_dir}"/*.rpm; do
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

      version="$(rpm -qp --qf "%{VERSION}\n" "${rpm_pkg}")"
      summary="$(rpm -qp --qf "%{SUMMARY}\n" "${rpm_pkg}")"
      ci_log "Version: ${version}"
      ci_log "Summary: ${summary}"
      if [[ "${version}" != "${expected_package_version}" ]]; then
        ci_die "Unexpected RPM package version in ${rpm_pkg}: ${version}"
      fi
      if [[ "${summary}" != "${expected_package_summary}" ]]; then
        ci_die "Unexpected RPM package summary in ${rpm_pkg}: ${summary}"
      fi
    done)
else
  ci_warn "rpm not available; skipping RPM architecture checks"
fi

ci_log "==> Verify RPM license metadata"
if ci_has_cmd rpm; then
  ( \
    for rpm_pkg in "${packaging_packages_dir}"/*.rpm; do
      [[ -f "${rpm_pkg}" ]] || continue
      ci_log "Checking ${rpm_pkg}..."
      license="$(rpm -qp --qf "%{LICENSE}\n" "${rpm_pkg}")"
      ci_log "License: ${license}"
      if [[ "${license}" != "${expected_package_license}" ]]; then
        ci_die "Unexpected RPM license metadata in ${rpm_pkg}: ${license}"
      fi
    done)
else
  ci_warn "rpm not available; skipping RPM license checks"
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
( \
  has_deb=false && has_rpm=false && \
  ls "${packaging_packages_dir}"/*.deb >/dev/null 2>&1 && has_deb=true || true && \
  ls "${packaging_packages_dir}"/*.rpm >/dev/null 2>&1 && has_rpm=true || true && \
  if [[ "${has_deb}" == "true" ]]; then
    bash "${packaging_dir}/test-packages.sh" --packages-dir "${packaging_packages_dir}" ubuntu
  else
    ci_warn "No .deb packages found; skipping Ubuntu container test"
  fi && \
  if [[ "${has_rpm}" == "true" ]]; then
    bash "${packaging_dir}/test-packages.sh" --packages-dir "${packaging_packages_dir}" fedora
  else
    ci_warn "No .rpm packages found; skipping Fedora container test"
  fi)
