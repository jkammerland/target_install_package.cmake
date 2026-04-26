#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"

fail() {
  echo "[proof] $*" >&2
  exit 1
}

rm -rf "${work_root}"
mkdir -p "${work_root}/staging/usr/local/bin" "${work_root}/staging/usr/bin" "${work_root}/wrappers" "${work_root}/work"

printf 'plain script\n' >"${work_root}/staging/usr/local/bin/helper"
printf 'fake elf\n' >"${work_root}/staging/usr/bin/proof_app"
chmod +x "${work_root}/staging/usr/local/bin/helper" "${work_root}/staging/usr/bin/proof_app"

cat >"${work_root}/wrappers/file" <<EOF
#!/usr/bin/env bash
for path in "\$@"; do
  case "\$path" in
    */proof_app|*/app_one|*/app_two)
      printf '%s: ELF 64-bit LSB executable\\n' "\$path"
      ;;
    *)
      printf '%s: ASCII text executable\\n' "\$path"
      ;;
  esac
done
EOF

cat >"${work_root}/wrappers/podman" <<EOF
#!/usr/bin/env bash
case "\$1" in
  build)
    shift
    while [ "\$#" -gt 0 ]; do
      case "\$1" in
        -f)
          printf '%s\\n' "\$2" >"${work_root}/containerfile-path.txt"
          shift 2
          ;;
        -t)
          printf '%s\\n' "\$2" >"${work_root}/image-ref.txt"
          shift 2
          ;;
        *)
          context="\$1"
          shift
          ;;
      esac
    done
    printf '%s\\n' "\${context:-}" >"${work_root}/build-context.txt"
    ;;
  save)
    shift
    while [ "\$#" -gt 0 ]; do
      case "\$1" in
        --format)
          printf '%s\\n' "\$2" >"${work_root}/archive-format.txt"
          shift 2
          ;;
        -o)
          printf 'archive\\n' >"\$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    ;;
  images)
    printf '1 MB\\n'
    ;;
  *)
    echo "unexpected podman command: \$*" >&2
    exit 99
    ;;
esac
EOF

chmod +x "${work_root}/wrappers/file" "${work_root}/wrappers/podman"

archive_path="${work_root}/proof.oci.tar"
if ! STAGING_DIR="${work_root}/staging" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-build" \
  CONTAINER_TAG="1.0" \
  CONTAINER_RUNTIME="podman" \
  CONTAINER_ARCHIVE="${archive_path}" \
  CONTAINER_ARCHIVE_FORMAT="oci-archive" \
  PATH="${work_root}/wrappers:$PATH" \
  bash "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/build.log" 2>&1; then
  cat "${work_root}/build.log" >&2
  fail "build_minimal_container.sh should find the executable after a script-only preferred directory"
fi

grep -F "Using entrypoint: /usr/bin/proof_app" "${work_root}/build.log" >/dev/null || fail "Expected /usr/bin/proof_app entrypoint"
grep -F "${work_root}/staging" "${work_root}/build-context.txt" >/dev/null || fail "Expected staging directory as build context"
grep -F "proof-build:1.0" "${work_root}/image-ref.txt" >/dev/null || fail "Expected configured image reference"
grep -F "oci-archive" "${work_root}/archive-format.txt" >/dev/null || fail "Expected configured archive format"
[[ -f "${archive_path}" ]] || fail "Expected configured archive path"

docker_only_wrappers="${work_root}/docker-only-wrappers"
mkdir -p "${docker_only_wrappers}"
cat >"${docker_only_wrappers}/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker fallback must not be used" >&2
exit 99
EOF
chmod +x "${docker_only_wrappers}/docker"

if STAGING_DIR="${work_root}/staging" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-no-fallback" \
  CONTAINER_TAG="1.0" \
  PATH="${docker_only_wrappers}" \
  "${BASH}" "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/no-fallback.log" 2>&1; then
  fail "build_minimal_container.sh should default to podman and not fall back to docker"
fi
grep -F "Configured container runtime not found: podman" "${work_root}/no-fallback.log" >/dev/null || fail "Expected explicit podman-not-found diagnostic"

multi_staging="${work_root}/multi-staging"
mkdir -p "${multi_staging}/usr/local/bin" "${multi_staging}/usr/bin"
printf 'fake elf one\n' >"${multi_staging}/usr/local/bin/app_one"
printf 'fake elf two\n' >"${multi_staging}/usr/bin/app_two"
chmod +x "${multi_staging}/usr/local/bin/app_one" "${multi_staging}/usr/bin/app_two"

if STAGING_DIR="${multi_staging}" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-multi" \
  CONTAINER_TAG="1.0" \
  CONTAINER_RUNTIME="podman" \
  PATH="${work_root}/wrappers:$PATH" \
  bash "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/multi.log" 2>&1; then
  fail "build_minimal_container.sh should require explicit entrypoint for multiple ELF candidates"
fi
grep -F "Multiple executable candidates found" "${work_root}/multi.log" >/dev/null || fail "Expected multiple-candidates diagnostic"

if STAGING_DIR="${work_root}/staging" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-bad-entrypoint" \
  CONTAINER_TAG="1.0" \
  CONTAINER_RUNTIME="podman" \
  CONTAINER_ENTRYPOINT="/../usr/bin/proof_app" \
  PATH="${work_root}/wrappers:$PATH" \
  bash "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/bad-entrypoint.log" 2>&1; then
  fail "build_minimal_container.sh should reject entrypoints containing '..'"
fi
grep -F "must not contain '..'" "${work_root}/bad-entrypoint.log" >/dev/null || fail "Expected invalid entrypoint diagnostic"

nonexec_staging="${work_root}/nonexec-staging"
mkdir -p "${nonexec_staging}/usr/bin"
printf 'not executable\n' >"${nonexec_staging}/usr/bin/proof_app"
if STAGING_DIR="${nonexec_staging}" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-auto-nonexec" \
  CONTAINER_TAG="1.0" \
  CONTAINER_RUNTIME="podman" \
  PATH="${work_root}/wrappers:$PATH" \
  bash "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/auto-nonexec.log" 2>&1; then
  fail "build_minimal_container.sh should not auto-discover non-executable ELF files"
fi
grep -F "No executable found" "${work_root}/auto-nonexec.log" >/dev/null || fail "Expected no executable diagnostic for non-executable ELF"

if STAGING_DIR="${nonexec_staging}" \
  WORK_DIR="${work_root}/work" \
  CONTAINER_NAME="proof-nonexec" \
  CONTAINER_TAG="1.0" \
  CONTAINER_RUNTIME="podman" \
  CONTAINER_ENTRYPOINT="/usr/bin/proof_app" \
  PATH="${work_root}/wrappers:$PATH" \
  bash "${repo_root}/cmake/build_minimal_container.sh" >"${work_root}/nonexec.log" 2>&1; then
  fail "build_minimal_container.sh should reject a non-executable explicit entrypoint"
fi
grep -F "is not executable" "${work_root}/nonexec.log" >/dev/null || fail "Expected non-executable entrypoint diagnostic"

echo "[proof] build_minimal_container proof passed."
