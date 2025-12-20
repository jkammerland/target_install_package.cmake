#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

ci_setup_ccache "${ci_root}"

usage() {
  cat <<'EOF'
Usage: ci/run.sh cpack [options]

Suites:
  basic          CPack basic example + signing setup (matrix-friendly)
  components     CPack components example integration (Linux)
  cross-platform Cross-platform artifact analysis (Linux, after download-artifact)
  regression     Run tests/cpack-regression/run-all-tests.sh (Linux)

Options:
  --suite <name>         Suite to run (default: basic)
  --build-type <type>    Build type (default: Release)
  --cc <path>            C compiler for configure
  --cxx <path>           C++ compiler for configure
  --artifacts-dir <dir>  For cross-platform suite (default: ./artifacts)
  -h, --help             Show help
EOF
}

suite="basic"
build_type="Release"
cc=""
cxx=""
artifacts_dir="${ci_root}/artifacts"

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
    --build-type)
      build_type="${2:?}"
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
    --artifacts-dir)
      artifacts_dir="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

ci_require_cmd cmake

generate_test_gpg_key() {
  ci_require_cmd gpg
  cat >"${ci_root}/build/ci-deps/key-gen-batch" <<'EOF'
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: CI Test User
Name-Email: ci-test@target-install-package.local
Expire-Date: 0
%no-protection
%commit
EOF

  gpg --batch --generate-key "${ci_root}/build/ci-deps/key-gen-batch"
  gpg --list-keys ci-test@target-install-package.local >/dev/null
  export GPG_SIGNING_KEY="ci-test@target-install-package.local"
}

enable_gpg_signing_in_cpack_basic() {
  local example_dir="${ci_root}/examples/cpack-basic"
  local cmakelists="${example_dir}/CMakeLists.txt"
  local backup="${example_dir}/CMakeLists.txt.backup.ci"

  cp "${cmakelists}" "${backup}"

  awk '
  /^export_cpack\(/ { in_export=1 }
  in_export && /^)$/ {
    print "  GPG_SIGNING_KEY \"$ENV{GPG_SIGNING_KEY}\""
    print "  GENERATE_CHECKSUMS ON"
  }
  { print }
  in_export && /^)$/ { in_export=0 }
  ' "${backup}" >"${cmakelists}"

  trap 'mv -f "${backup}" "${cmakelists}"' RETURN
}

run_basic() {
  ci_log "==> Generate test GPG key"
  mkdir -p "${ci_root}/build/ci-deps"
  generate_test_gpg_key

  ci_log "==> Enable signing in examples/cpack-basic (temporary)"
  enable_gpg_signing_in_cpack_basic

  build_dir="${ci_root}/examples/cpack-basic/build"
  rm -rf "${build_dir}"
  mkdir -p "${build_dir}"

  ci_log "==> Configure examples/cpack-basic"
  cmake -S "${ci_root}/examples/cpack-basic" -B "${build_dir}" \
    ${cc:+-DCMAKE_C_COMPILER=${cc}} \
    ${cxx:+-DCMAKE_CXX_COMPILER=${cxx}} \
    -DCMAKE_BUILD_TYPE="${build_type}" \
    -DCMAKE_INSTALL_PREFIX=./install \
    -DPROJECT_LOG_COLORS=OFF

  ci_log "==> Build examples/cpack-basic"
  cmake --build "${build_dir}" --config "${build_type}"

  ci_log "==> Install all components"
  cmake --install "${build_dir}" --config "${build_type}"

  ci_log "==> Install component subsets"
  cmake --install "${build_dir}" --config "${build_type}" --component Runtime --prefix "${build_dir}/runtime-only"
  cmake --install "${build_dir}" --config "${build_type}" --component Development --prefix "${build_dir}/dev-only"
  cmake --install "${build_dir}" --config "${build_type}" --component Tools --prefix "${build_dir}/tools-only"

  ci_log "==> Generate packages (cpack)"
  (cd "${build_dir}" && cpack --verbose)

  ci_log "==> Generated artifacts"
  (cd "${build_dir}" && ls -la *.tar.gz *.zip *.deb *.rpm *.dmg 2>/dev/null || true)
  (cd "${build_dir}" && ls -la *.sig *.sha256 *.sha512 verify.sh 2>/dev/null || true)

  ci_log "==> Verify component tgz contents"
  (cd "${build_dir}" && \
    runtime_has_exe="$(tar -tzf MyLibrary-*-Runtime.tar.gz | grep -c \"bin/mytool\" || true)" && \
    dev_has_headers="$(tar -tzf MyLibrary-*-Development.tar.gz | grep -c \"include/\" || true)" && \
    tools_has_exe="$(tar -tzf MyLibrary-*-TOOLS.tar.gz | grep -c \"bin/mytool\" || true)" && \
    [[ "${runtime_has_exe}" == "0" ]] || exit 1 && \
    [[ "${dev_has_headers}" != "0" ]] || exit 1 && \
    [[ "${tools_has_exe}" != "0" ]] || exit 1)

  ci_log "==> Verify signatures (if present)"
  (cd "${build_dir}" && \
    for pkg in *.tar.gz *.deb *.rpm *.zip *.dmg; do
      [[ -f "${pkg}" ]] || continue
      [[ -f "${pkg}.sig" ]] || continue
      gpg --verify "${pkg}.sig" "${pkg}" >/dev/null
    done)

  ci_log "==> Test package extraction + basic validation (TGZ)"
  (cd "${build_dir}" && \
    rm -rf test-runtime test-dev test-tools-alone test-tools-with-deps && \
    mkdir -p test-runtime test-dev test-tools-alone test-tools-with-deps && \
    (cd test-runtime && tar -xzf ../MyLibrary-*-Runtime.tar.gz) && \
    (cd test-dev && tar -xzf ../MyLibrary-*-Development.tar.gz) && \
    (cd test-tools-alone && tar -xzf ../MyLibrary-*-TOOLS.tar.gz) && \
    (cd test-tools-with-deps && tar -xzf ../MyLibrary-*-TOOLS.tar.gz && tar -xzf ../MyLibrary-*-Runtime.tar.gz))

  (cd "${build_dir}/test-runtime" && \
    if ci_is_windows; then
      libext="dll"
    elif ci_is_macos; then
      libext="dylib"
    else
      libext="so"
    fi && \
    if find . -name "*cpack_lib*.${libext}*" | grep -q .; then
      ci_log "✓ Runtime library present (${libext})"
    else
      ci_die "Runtime library not found in Runtime package"
    fi)

  (cd "${build_dir}/test-dev" && \
    find . -name "*.h" | grep -q . || ci_die "Development headers not found" && \
    find . -name "*Config.cmake" -o -name "*config.cmake" | grep -q . || ci_die "CMake config files not found")

  ci_log "==> Tool package dependency chain (Tools + Runtime)"
  if ci_is_windows; then
    ci_log "Skipping tool runtime execution test on Windows (DLL loading in CI)"
  else
    (cd "${build_dir}/test-tools-with-deps" && \
      tool_path="$(find . -name mytool -type f | head -n 1)" && \
      [[ -n "${tool_path}" ]] || ci_die "mytool not found" && \
      chmod +x "${tool_path}" && \
      if ci_is_linux; then
        readelf -d "${tool_path}" | grep -E "RPATH|RUNPATH" || true
      elif ci_is_macos; then
        otool -L "${tool_path}" || true
      fi && \
      "${tool_path}" --version)
  fi
}

run_components() {
  if ! ci_is_linux; then
    ci_die "components suite is Linux-only"
  fi

  build_dir="${ci_root}/examples/components/build"
  rm -rf "${build_dir}"
  mkdir -p "${build_dir}"

  ci_log "==> Configure examples/components"
  cmake -S "${ci_root}/examples/components" -B "${build_dir}" -DCMAKE_INSTALL_PREFIX=./install

  ci_log "==> Build + install examples/components"
  cmake --build "${build_dir}"
  cmake --install "${build_dir}"

  ci_log "==> cpack (components)"
  (cd "${build_dir}" && cpack --verbose)

  (cd "${build_dir}" && ls -la MediaLibrary-*.tar.gz MediaLibrary-*.deb 2>/dev/null || true)
  if (cd "${build_dir}" && ls MediaLibrary-*-CORE.tar.gz 1>/dev/null 2>&1); then
    ci_log "✓ Components example produced CORE group package"
  else
    ci_die "Components example did not produce expected CORE group package"
  fi
}

run_cross_platform() {
  if ! ci_is_linux; then
    ci_die "cross-platform suite is Linux-only"
  fi
  if [[ ! -d "${artifacts_dir}" ]]; then
    ci_die "Artifacts dir not found: ${artifacts_dir}"
  fi

  ci_log "==> Cross-platform artifact analysis: ${artifacts_dir}"
  (cd "${artifacts_dir}" && \
    for platform in */; do
      ci_log "=== Platform: ${platform} ==="
      cd "${platform}"
      ls -la *.tar.gz *.zip *.deb *.rpm *.dmg 2>/dev/null || true
      ls -la *.sig 2>/dev/null || true
      ls -la *.sha256 *.sha512 2>/dev/null || true
      ls -la verify.sh 2>/dev/null || true

      if ls *-Runtime.tar.gz 1>/dev/null 2>&1; then
        ci_log "✓ Runtime component package found"
      else
        ci_warn "Runtime component package missing"
      fi
      if ls *-Development.tar.gz 1>/dev/null 2>&1; then
        ci_log "✓ Development component package found"
      else
        ci_warn "Development component package missing"
      fi
      if ls *-TOOLS.tar.gz 1>/dev/null 2>&1; then
        ci_log "✓ Tools component package found"
      else
        ci_warn "Tools component package missing"
      fi

      ci_log "Signature coverage:"
      for pkg in *.tar.gz *.zip *.deb *.rpm *.dmg; do
        [[ -f "${pkg}" ]] || continue
        if [[ -f "${pkg}.sig" ]]; then
          ci_log "✓ ${pkg} has signature"
        else
          ci_warn "${pkg} missing signature"
        fi
      done

      cd ..
    done)
}

run_regression() {
  if ! ci_is_linux; then
    ci_die "regression suite is Linux-only"
  fi
  ci_log "==> CPack regression tests"
  (cd "${ci_root}/tests/cpack-regression" && bash run-all-tests.sh)
}

case "${suite}" in
  basic) run_basic ;;
  components) run_components ;;
  cross-platform) run_cross_platform ;;
  regression) run_regression ;;
  *)
    usage >&2
    ci_die "Unknown suite: ${suite}"
    ;;
esac
