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
mkdir -p "${work_root}/case-missing/staging/bin" "${work_root}/case-missing/wrappers" "${work_root}/case-missing/logs"

preserve_staging_dir="${work_root}/case-preserve/staging"
preserve_wrappers_dir="${work_root}/case-preserve/wrappers"
preserve_logs_dir="${work_root}/case-preserve/logs"

printf 'fake-elf\n' >"${preserve_staging_dir}/bin/proof_app"
chmod +x "${preserve_staging_dir}/bin/proof_app"

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
libc.so.6 => /lib64/libc.so.6 (0x00000000)
/lib/ld-linux.so.2 (0x00000000)
OUT
    ;;
  "/lib64/libc.so.6")
    cat <<'OUT'
linux-vdso.so.1 (0x00000000)
/lib64/ld-linux-x86-64.so.2 (0x00000000)
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

[[ -f "${preserve_staging_dir}/lib64/libc.so.6" ]] || fail "Expected copied libc dependency"
[[ -f "${preserve_staging_dir}/lib/ld-linux.so.2" ]] || fail "Expected interpreter preserved at /lib"
[[ ! -f "${preserve_staging_dir}/lib64/ld-linux.so.2" ]] || fail "Interpreter should not be relocated into lib64"

grep -F "Collected" "${preserve_logs_dir}/collect.log" >/dev/null || fail "Expected summary line in collect log"

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
