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
  basic          CPack basic example + signing setup (safe for per-job CI matrix execution)
  components     CPack components example integration (Linux)
  cross-platform Cross-platform artifact analysis (Linux, after download-artifact)
  regression     Run tests/cpack-regression/run-all-tests.sh (Linux)

Options:
  --suite <name>         Suite to run (default: basic)
  --build-type <type>    Build type (default: Release)
  --cc <path>            C compiler for configure
  --cxx <path>           C++ compiler for configure
  --artifacts-dir <dir>  For cross-platform suite (default: ./build/cpack/artifacts)
  -h, --help             Show help
EOF
}

suite="basic"
build_type="Release"
cc=""
cxx=""
artifacts_dir="${ci_root}/build/cpack/artifacts"

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
  local cmakelists="${1:?}"
  local tmp="${cmakelists}.tmp"
  awk '
  /^export_cpack\(/ { in_export=1 }
  in_export && /^)$/ {
    print "  GPG_SIGNING_KEY \"$ENV{GPG_SIGNING_KEY}\""
    print "  GENERATE_CHECKSUMS ON"
  }
  { print }
  in_export && /^)$/ { in_export=0 }
  ' "${cmakelists}" >"${tmp}"
  mv -f "${tmp}" "${cmakelists}"
}

rewrite_example_repo_paths() {
  local cmakelists="${1:?}"
  local repo_root="${2:?}"
  local tmp="${cmakelists}.tmp"
  local loader_path
  local license_file
  local root_cmakelists
  loader_path="$(ci_path_for_cmake "${repo_root}/cmake/load_target_install_package.cmake")"
  license_file="$(ci_path_for_cmake "${repo_root}/LICENSE")"
  root_cmakelists="$(ci_path_for_cmake "${repo_root}/CMakeLists.txt")"

  awk -v loader_path="${loader_path}" -v license_file="${license_file}" -v root_cmakelists="${root_cmakelists}" '
    {
      compact=$0
      rewritten=$0
      gsub(/[[:space:]]+/, "", compact)

      if (compact == "include(../../CMakeLists.txt)") {
        print "include(\"" root_cmakelists "\")"
      } else if (compact == "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)") {
        print "include(\"" loader_path "\")"
      } else {
        gsub(/\$\{CMAKE_CURRENT_SOURCE_DIR\}\/\.\.\/\.\.\/LICENSE/, license_file, rewritten)
        print rewritten
      }
    }
  ' "${cmakelists}" >"${tmp}"
  mv -f "${tmp}" "${cmakelists}"
}

find_one_artifact() {
  local pattern="${1:?}"
  local matches=()
  shopt -s nullglob
  matches=( ${pattern} )
  shopt -u nullglob
  if [[ "${#matches[@]}" -ne 1 ]]; then
    ci_die "Expected exactly one artifact matching '${pattern}', found ${#matches[@]}"
  fi
  printf '%s\n' "${matches[0]}"
}

assert_artifact_count() {
  local context="${1:?}"
  local expected_count="${2:?}"
  shift 2
  local artifacts=("$@")
  if (( ${#artifacts[@]} != expected_count )); then
    printf '%s\n' "${artifacts[@]}" >&2
    ci_die "Expected ${expected_count} ${context}, found ${#artifacts[@]}"
  fi
}

deb_control_field() {
  local deb="${1:?}"
  local field="${2:?}"
  local control=""
  local member=""

  if ci_has_cmd dpkg-deb; then
    dpkg-deb -f "${deb}" "${field}"
    return 0
  fi

  ci_require_cmd ar
  member="$(ar t "${deb}" | awk '/^control\.tar/ { print; exit }')"
  [[ -n "${member}" ]] || ci_die "No control archive found in ${deb}"

  case "${member}" in
    *.gz) control="$(ar p "${deb}" "${member}" | tar -xzO -f - ./control)" ;;
    *.xz) control="$(ar p "${deb}" "${member}" | tar -xJO -f - ./control)" ;;
    *.zst) control="$(ar p "${deb}" "${member}" | tar --zstd -xO -f - ./control)" ;;
    *.bz2) control="$(ar p "${deb}" "${member}" | tar -xjO -f - ./control)" ;;
    *) control="$(ar p "${deb}" "${member}" | tar -xO -f - ./control)" ;;
  esac

  awk -v field="${field}" '
    BEGIN { prefix = field ":" }
    index($0, prefix) == 1 {
      print substr($0, length(prefix) + 2)
      found = 1
      next
    }
    found && /^[[:space:]]/ {
      sub(/^[[:space:]]+/, "")
      print
      next
    }
    found { exit }
  ' <<<"${control}"
}

trim_value() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

assert_deb_dependency() {
  local depends="${1-}"
  local expected="${2:?}"
  local context="${3:?}"
  local token
  local dependencies=()

  IFS=',' read -r -a dependencies <<<"${depends}"
  for token in "${dependencies[@]}"; do
    token="$(trim_value "${token}")"
    if [[ "${token}" == "${expected}" ]]; then
      return 0
    fi
  done

  ci_die "${context} did not contain exact dependency '${expected}'. Actual value: ${depends}"
}

assert_rpm_requirement() {
  local value="${1-}"
  local expected="${2:?}"
  local context="${3:?}"
  local line

  while IFS= read -r line; do
    line="$(trim_value "${line}")"
    if [[ "${line}" == "${expected}" ]]; then
      return 0
    fi
  done <<<"${value}"

  ci_die "${context} did not contain exact requirement '${expected}'. Actual value: ${value}"
}

verify_native_component_dependencies() {
  if ! ci_is_linux; then
    return 0
  fi

  ci_log "==> Verify native component package dependencies"

  shopt -s nullglob
  local deb_artifacts=(mylibrary-*.deb)
  local rpm_artifacts=(mylibrary-*.rpm)
  shopt -u nullglob
  assert_artifact_count "DEB component packages" 3 "${deb_artifacts[@]}"
  assert_artifact_count "RPM component packages" 3 "${rpm_artifacts[@]}"

  local development_deb runtime_deb tools_deb
  development_deb="$(find_one_artifact "mylibrary-development_*.deb")"
  runtime_deb="$(find_one_artifact "mylibrary-runtime_*.deb")"
  tools_deb="$(find_one_artifact "mylibrary-tools_*.deb")"

  local development_deb_depends runtime_deb_name runtime_deb_version tools_deb_name tools_deb_version
  development_deb_depends="$(deb_control_field "${development_deb}" "Depends")"
  runtime_deb_name="$(deb_control_field "${runtime_deb}" "Package")"
  runtime_deb_version="$(deb_control_field "${runtime_deb}" "Version")"
  tools_deb_name="$(deb_control_field "${tools_deb}" "Package")"
  tools_deb_version="$(deb_control_field "${tools_deb}" "Version")"
  assert_deb_dependency "${development_deb_depends}" "${runtime_deb_name} (= ${runtime_deb_version})" "Development DEB Depends"
  assert_deb_dependency "${development_deb_depends}" "${tools_deb_name} (= ${tools_deb_version})" "Development DEB Depends"

  ci_require_cmd rpm
  local development_rpm runtime_rpm tools_rpm
  development_rpm="$(find_one_artifact "mylibrary-Development-*.rpm")"
  runtime_rpm="$(find_one_artifact "mylibrary-Runtime-*.rpm")"
  tools_rpm="$(find_one_artifact "mylibrary-Tools-*.rpm")"

  local development_rpm_requires runtime_rpm_name runtime_rpm_version_release tools_rpm_name tools_rpm_version_release
  development_rpm_requires="$(rpm -qp --requires "${development_rpm}")"
  runtime_rpm_name="$(rpm -qp --queryformat '%{NAME}\n' "${runtime_rpm}")"
  runtime_rpm_version_release="$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}\n' "${runtime_rpm}")"
  tools_rpm_name="$(rpm -qp --queryformat '%{NAME}\n' "${tools_rpm}")"
  tools_rpm_version_release="$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}\n' "${tools_rpm}")"
  assert_rpm_requirement "${development_rpm_requires}" "${runtime_rpm_name} = ${runtime_rpm_version_release}" "Development RPM Requires"
  assert_rpm_requirement "${development_rpm_requires}" "${tools_rpm_name} = ${tools_rpm_version_release}" "Development RPM Requires"
}

run_basic() {
  ci_log "==> Generate test GPG key"
  mkdir -p "${ci_root}/build/ci-deps"
  generate_test_gpg_key

  work_dir="${ci_root}/build/cpack/basic"
  src_dir="${work_dir}/src"
  build_dir="${work_dir}/build"
  rm -rf "${build_dir}"
  rm -rf "${src_dir}"
  mkdir -p "${src_dir}" "${build_dir}"

  ci_log "==> Prepare cpack-basic workspace"
  cp -a "${ci_root}/examples/cpack-basic/." "${src_dir}"
  rewrite_example_repo_paths "${src_dir}/CMakeLists.txt" "${ci_root}"
  enable_gpg_signing_in_cpack_basic "${src_dir}/CMakeLists.txt"

  ci_log "==> Configure cpack-basic"
  cmake --log-level=DEBUG -S "${src_dir}" -B "${build_dir}" \
    ${cc:+-DCMAKE_C_COMPILER=${cc}} \
    ${cxx:+-DCMAKE_CXX_COMPILER=${cxx}} \
    -DCMAKE_BUILD_TYPE="${build_type}" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DPROJECT_LOG_COLORS=ON

  ci_log "==> Build cpack-basic"
  cmake --build "${build_dir}" --config "${build_type}"

  ci_log "==> Install all components"
  cmake --install "${build_dir}" --config "${build_type}" --prefix "${build_dir}/install"

  ci_log "==> Install component subsets"
  cmake --install "${build_dir}" --config "${build_type}" --component Runtime --prefix "${build_dir}/runtime-only"
  cmake --install "${build_dir}" --config "${build_type}" --component Development --prefix "${build_dir}/dev-only"
  cmake --install "${build_dir}" --config "${build_type}" --component Tools --prefix "${build_dir}/tools-only"

  ci_log "==> Generate packages (cpack)"
  (cd "${build_dir}" && cpack --verbose)

  (cd "${build_dir}" && verify_native_component_dependencies)

  ci_log "==> Generated artifacts"
  (cd "${build_dir}" && ls -la *.tar.gz *.zip *.deb *.rpm *.dmg 2>/dev/null || true)
  (cd "${build_dir}" && ls -la *.sig *.sha256 *.sha512 verify.sh 2>/dev/null || true)

  ci_log "==> Verify component tgz contents"
  (cd "${build_dir}" && \
    runtime_has_exe="$(tar -tzf MyLibrary-*-Runtime.tar.gz | grep -c 'bin/mytool' || true)" && \
    dev_has_headers="$(tar -tzf MyLibrary-*-Development.tar.gz | grep -c 'include/' || true)" && \
    tools_has_exe="$(tar -tzf MyLibrary-*-Tools.tar.gz | grep -c 'bin/mytool' || true)" && \
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
    (cd test-tools-alone && tar -xzf ../MyLibrary-*-Tools.tar.gz) && \
    (cd test-tools-with-deps && tar -xzf ../MyLibrary-*-Tools.tar.gz && tar -xzf ../MyLibrary-*-Runtime.tar.gz))

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
        lib_path="$(find . -type f -name 'libcpack_lib.so*' | head -n 1 || true)"
        if [[ -n "${lib_path}" ]]; then
          lib_dir="$(dirname "${lib_path}")"
          LD_LIBRARY_PATH="${lib_dir}${LD_LIBRARY_PATH+:${LD_LIBRARY_PATH}}" "${tool_path}" --version
          exit 0
        fi
      elif ci_is_macos; then
        otool -L "${tool_path}" || true
        lib_path="$(find . -type f -name 'libcpack_lib*.dylib*' | head -n 1 || true)"
        if [[ -n "${lib_path}" ]]; then
          lib_dir="$(dirname "${lib_path}")"
          DYLD_LIBRARY_PATH="${lib_dir}${DYLD_LIBRARY_PATH+:${DYLD_LIBRARY_PATH}}" "${tool_path}" --version
          exit 0
        fi
      fi && \
      "${tool_path}" --version)
  fi
}

run_components() {
  if ! ci_is_linux; then
    ci_die "components suite is Linux-only"
  fi

  build_dir="${ci_root}/build/cpack/components"
  rm -rf "${build_dir}"
  mkdir -p "${build_dir}"

  ci_log "==> Configure examples/components"
  cmake --log-level=DEBUG -S "${ci_root}/examples/components" -B "${build_dir}" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DPROJECT_LOG_COLORS=ON

  ci_log "==> Build + install examples/components"
  cmake --build "${build_dir}"
  cmake --install "${build_dir}" --prefix "${build_dir}/install"

  ci_log "==> cpack (components)"
  (cd "${build_dir}" && cpack --verbose)

  (cd "${build_dir}" && ls -la MediaLibrary-*.tar.gz MediaLibrary-*.deb 2>/dev/null || true)
  if (cd "${build_dir}" && ls MediaLibrary-*-Core.tar.gz 1>/dev/null 2>&1); then
    ci_log "✓ Components example produced Core component package"
  else
    ci_die "Components example did not produce expected Core component package"
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
      if ls *-Tools.tar.gz 1>/dev/null 2>&1; then
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
  bash "${ci_root}/tests/cpack-regression/run-all-tests.sh" --work-dir "${ci_root}/build/cpack/regression"
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
