#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"

fail() {
  echo "[proof] $*" >&2
  exit 1
}

rm -rf "${work_root}"
mkdir -p "${work_root}/case-preserve/staging/bin" "${work_root}/case-preserve/wrappers" "${work_root}/case-preserve/logs"
mkdir -p "${work_root}/case-preserve/host/lib" "${work_root}/case-preserve/host/lib64"
mkdir -p "${work_root}/case-no-elf/staging/bin" "${work_root}/case-no-elf/wrappers" "${work_root}/case-no-elf/logs"
mkdir -p "${work_root}/case-static/staging/bin" "${work_root}/case-static/wrappers" "${work_root}/case-static/logs"
mkdir -p "${work_root}/case-stage-local/staging/bin" "${work_root}/case-stage-local/staging/usr/local/lib" "${work_root}/case-stage-local/wrappers" "${work_root}/case-stage-local/logs"
mkdir -p "${work_root}/case-missing/staging/bin" "${work_root}/case-missing/wrappers" "${work_root}/case-missing/logs"

preserve_staging_dir="${work_root}/case-preserve/staging"
preserve_wrappers_dir="${work_root}/case-preserve/wrappers"
preserve_logs_dir="${work_root}/case-preserve/logs"
preserve_host_dir="${work_root}/case-preserve/host"

printf 'fake-elf\n' >"${preserve_staging_dir}/bin/proof_app"
chmod +x "${preserve_staging_dir}/bin/proof_app"
printf 'fake-libc\n' >"${preserve_host_dir}/lib64/libc.so.6"
printf 'fake-loader\n' >"${preserve_host_dir}/lib/ld-linux.so.2"
printf 'fake-loader64\n' >"${preserve_host_dir}/lib64/ld-linux-x86-64.so.2"

cat >"${preserve_wrappers_dir}/file" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  printf '%s: ELF 64-bit LSB executable\n' "$path"
done
EOF

cat >"${preserve_wrappers_dir}/ldd" <<EOF
#!/usr/bin/env bash
case "\$1" in
  "${preserve_staging_dir}/bin/proof_app")
    cat <<'OUT'
linux-vdso.so.1 (0x00000000)
libc.so.6 => ${preserve_host_dir}/lib64/libc.so.6 (0x00000000)
${preserve_host_dir}/lib/ld-linux.so.2 (0x00000000)
OUT
    ;;
  "${preserve_host_dir}/lib64/libc.so.6")
    cat <<'OUT'
linux-vdso.so.1 (0x00000000)
${preserve_host_dir}/lib64/ld-linux-x86-64.so.2 (0x00000000)
OUT
    ;;
  *)
    ;;
esac
EOF

chmod +x "${preserve_wrappers_dir}/file" "${preserve_wrappers_dir}/ldd"

if ! STAGING_DIR="${preserve_staging_dir}" PATH="${preserve_wrappers_dir}:$PATH" bash "${repo_root}/cmake/collect_runtime_deps.sh" >"${preserve_logs_dir}/collect.log" 2>&1; then
  cat "${preserve_logs_dir}/collect.log" >&2
  fail "collect_runtime_deps.sh should succeed for the preserve-path case"
fi

[[ -f "${preserve_staging_dir}${preserve_host_dir}/lib64/libc.so.6" ]] || fail "Expected copied libc dependency"
[[ -f "${preserve_staging_dir}${preserve_host_dir}/lib/ld-linux.so.2" ]] || fail "Expected interpreter path to be preserved"
[[ ! -f "${preserve_staging_dir}${preserve_host_dir}/lib64/ld-linux.so.2" ]] || fail "Interpreter should not be relocated into lib64"

grep -F "Collected" "${preserve_logs_dir}/collect.log" >/dev/null || fail "Expected summary line in collect log"

no_elf_staging_dir="${work_root}/case-no-elf/staging"
no_elf_wrappers_dir="${work_root}/case-no-elf/wrappers"
no_elf_logs_dir="${work_root}/case-no-elf/logs"

printf 'plain text\n' >"${no_elf_staging_dir}/bin/proof_script"
chmod +x "${no_elf_staging_dir}/bin/proof_script"

cat >"${no_elf_wrappers_dir}/file" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  printf '%s: ASCII text executable\n' "$path"
done
EOF

cat >"${no_elf_wrappers_dir}/ldd" <<'EOF'
#!/usr/bin/env bash
echo "ldd should not be called for non-ELF files" >&2
exit 99
EOF

chmod +x "${no_elf_wrappers_dir}/file" "${no_elf_wrappers_dir}/ldd"

if ! STAGING_DIR="${no_elf_staging_dir}" PATH="${no_elf_wrappers_dir}:$PATH" bash "${repo_root}/cmake/collect_runtime_deps.sh" >"${no_elf_logs_dir}/collect.log" 2>&1; then
  cat "${no_elf_logs_dir}/collect.log" >&2
  fail "collect_runtime_deps.sh should warn and succeed when no ELF files are present"
fi
grep -F "WARNING: No ELF binaries found" "${no_elf_logs_dir}/collect.log" >/dev/null || fail "Expected no-ELF warning"

static_staging_dir="${work_root}/case-static/staging"
static_wrappers_dir="${work_root}/case-static/wrappers"
static_logs_dir="${work_root}/case-static/logs"

printf 'fake-static-elf\n' >"${static_staging_dir}/bin/proof_static"
chmod +x "${static_staging_dir}/bin/proof_static"

cat >"${static_wrappers_dir}/file" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  printf '%s: ELF 64-bit LSB executable, statically linked\n' "$path"
done
EOF

cat >"${static_wrappers_dir}/ldd" <<'EOF'
#!/usr/bin/env bash
echo "not a dynamic executable"
exit 1
EOF

chmod +x "${static_wrappers_dir}/file" "${static_wrappers_dir}/ldd"

if ! STAGING_DIR="${static_staging_dir}" PATH="${static_wrappers_dir}:$PATH" bash "${repo_root}/cmake/collect_runtime_deps.sh" >"${static_logs_dir}/collect.log" 2>&1; then
  cat "${static_logs_dir}/collect.log" >&2
  fail "collect_runtime_deps.sh should accept static ELF executables"
fi

stage_local_staging_dir="${work_root}/case-stage-local/staging"
stage_local_wrappers_dir="${work_root}/case-stage-local/wrappers"
stage_local_logs_dir="${work_root}/case-stage-local/logs"

printf 'fake-elf\n' >"${stage_local_staging_dir}/bin/proof_app"
printf 'fake-lib\n' >"${stage_local_staging_dir}/usr/local/lib/libstage.so"
chmod +x "${stage_local_staging_dir}/bin/proof_app" "${stage_local_staging_dir}/usr/local/lib/libstage.so"

cat >"${stage_local_wrappers_dir}/file" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  printf '%s: ELF 64-bit LSB shared object\n' "$path"
done
EOF

cat >"${stage_local_wrappers_dir}/ldd" <<EOF
#!/usr/bin/env bash
case "\$1" in
  "${stage_local_staging_dir}/bin/proof_app")
    cat <<'OUT'
linux-vdso.so.1 (0x00000000)
libstage.so => ${stage_local_staging_dir}/usr/local/lib/libstage.so (0x00000000)
OUT
    ;;
  "${stage_local_staging_dir}/usr/local/lib/libstage.so")
    echo "not a dynamic executable"
    exit 1
    ;;
  *)
    ;;
esac
EOF

chmod +x "${stage_local_wrappers_dir}/file" "${stage_local_wrappers_dir}/ldd"

if ! (
  cd "${work_root}/case-stage-local"
  STAGING_DIR="staging" PATH="${stage_local_wrappers_dir}:$PATH" bash "${repo_root}/cmake/collect_runtime_deps.sh" >"${stage_local_logs_dir}/collect.log" 2>&1
); then
  cat "${stage_local_logs_dir}/collect.log" >&2
  fail "collect_runtime_deps.sh should accept relative staging roots and dependencies already inside the staging rootfs"
fi

[[ ! -e "${stage_local_staging_dir}${stage_local_staging_dir}/usr/local/lib/libstage.so" ]] || fail "Stage-local dependency should not be copied into a nested staging path"
grep -F "Already staged: ${stage_local_staging_dir}/usr/local/lib/libstage.so" "${stage_local_logs_dir}/collect.log" >/dev/null || fail "Expected already-staged dependency log"

missing_staging_dir="${work_root}/case-missing/staging"
missing_wrappers_dir="${work_root}/case-missing/wrappers"
missing_logs_dir="${work_root}/case-missing/logs"

printf 'fake-elf\n' >"${missing_staging_dir}/bin/proof_app"
chmod +x "${missing_staging_dir}/bin/proof_app"

cat >"${missing_wrappers_dir}/file" <<'EOF'
#!/usr/bin/env bash
for path in "$@"; do
  printf '%s: ELF 64-bit LSB executable\n' "$path"
done
EOF

cat >"${missing_wrappers_dir}/ldd" <<EOF
#!/usr/bin/env bash
case "\$1" in
  "${missing_staging_dir}/bin/proof_app")
    cat <<'OUT'
linux-vdso.so.1 (0x00000000)
libmissing.so => not found
/lib/ld-linux.so.2 (0x00000000)
OUT
    ;;
  *)
    ;;
esac
EOF

chmod +x "${missing_wrappers_dir}/file" "${missing_wrappers_dir}/ldd"

if STAGING_DIR="${missing_staging_dir}" PATH="${missing_wrappers_dir}:$PATH" bash "${repo_root}/cmake/collect_runtime_deps.sh" >"${missing_logs_dir}/collect.log" 2>&1; then
  cat "${missing_logs_dir}/collect.log" >&2
  fail "collect_runtime_deps.sh should fail when ldd reports a missing dependency"
fi

echo "[proof] collect_runtime_deps proof passed."
