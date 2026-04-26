#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"

fail() {
  echo "[proof] $*" >&2
  exit 1
}

rm -rf "${work_root}"
mkdir -p "${work_root}/staging/Runtime/usr/local/bin" "${work_root}/staging/Tools/etc/proof" "${work_root}/overlay/etc/ssl/certs" "${work_root}/wrappers" "${work_root}/top"

printf 'fake elf\n' >"${work_root}/staging/Runtime/usr/local/bin/proof_app"
printf 'tool data\n' >"${work_root}/staging/Tools/etc/proof/tool.conf"
printf 'ca data\n' >"${work_root}/overlay/etc/ssl/certs/proof-ca.pem"
chmod +x "${work_root}/staging/Runtime/usr/local/bin/proof_app"

cat >"${work_root}/wrappers/file" <<EOF
#!/usr/bin/env bash
case "\$1" in
  "${work_root}/top/container-rootfs/usr/local/bin/proof_app")
    printf '%s: ELF 64-bit LSB executable, statically linked\\n' "\$1"
    ;;
  *)
    printf '%s: ASCII text\\n' "\$1"
    ;;
esac
EOF

cat >"${work_root}/wrappers/ldd" <<'EOF'
#!/usr/bin/env bash
echo "not a dynamic executable"
exit 1
EOF

cat >"${work_root}/wrappers/podman" <<EOF
#!/usr/bin/env bash
case "\$1" in
  build)
    context="\${@: -1}"
    [ -f "\$context/usr/local/bin/proof_app" ] || exit 41
    [ -f "\$context/etc/proof/tool.conf" ] || exit 42
    [ -f "\$context/etc/ssl/certs/proof-ca.pem" ] || exit 43
    ;;
  save)
    shift
    while [ "\$#" -gt 0 ]; do
      case "\$1" in
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

chmod +x "${work_root}/wrappers/file" "${work_root}/wrappers/ldd" "${work_root}/wrappers/podman"

if ! PATH="${work_root}/wrappers:$PATH" cmake \
  "-DCPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER=ON" \
  "-DCPACK_TEMPORARY_DIRECTORY=${work_root}/staging" \
  "-DCPACK_TOPLEVEL_DIRECTORY=${work_root}/top" \
  "-DCPACK_PACKAGE_NAME=proof_external" \
  "-DCPACK_PACKAGE_VERSION=1.0" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_NAME=proof-external" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_TAG=1.0" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_RUNTIME=podman" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_ENTRYPOINT=/usr/local/bin/proof_app" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_COMPONENTS=Runtime;Tools" \
  "-DCPACK_EXTERNAL_USER_CONTAINER_ROOTFS_OVERLAYS=${work_root}/overlay" \
  -P "${repo_root}/cmake/external_container_package.cmake" >"${work_root}/external.log" 2>&1; then
  cat "${work_root}/external.log" >&2
  fail "external_container_package.cmake should merge explicit container components"
fi

[[ -f "${work_root}/top/container-rootfs/usr/local/bin/proof_app" ]] || fail "Expected Runtime component in merged rootfs"
[[ -f "${work_root}/top/container-rootfs/etc/proof/tool.conf" ]] || fail "Expected Tools component in merged rootfs"
[[ -f "${work_root}/top/container-rootfs/etc/ssl/certs/proof-ca.pem" ]] || fail "Expected overlay content in merged rootfs"
[[ -f "${work_root}/top/proof-external-1.0-oci-archive.tar" ]] || fail "Expected CPack-visible container archive"

echo "[proof] external container package proof passed."
