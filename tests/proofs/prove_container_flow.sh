#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"
container_runtime="${3:-podman}"

fail() {
  echo "[proof] $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Expected file: $path"
}

assert_contains() {
  local needle="$1"
  local path="$2"
  grep -Fqx "$needle" "$path" || fail "Expected '$needle' in $path"
}

assert_not_contains() {
  local needle="$1"
  local path="$2"
  if grep -Fqx "$needle" "$path"; then
    fail "Did not expect '$needle' in $path"
  fi
}

run_logged() {
  local log_path="$1"
  shift
  if ! "$@" >"${log_path}" 2>&1; then
    cat "${log_path}" >&2
    fail "Command failed: $*"
  fi
}

case "${container_runtime}" in
  podman|docker)
    ;;
  *)
    fail "Unsupported container runtime: ${container_runtime}"
    ;;
esac

command -v "${container_runtime}" >/dev/null 2>&1 || fail "Container runtime not found: ${container_runtime}"

build_dir="${work_root}/build"
log_dir="${work_root}/logs"
image_name="tip-proof-$(basename "${work_root}" | tr -cd '[:alnum:]_.-')-$$"
image_tag="1.0.0"
archive_format="oci-archive"
if [[ "${container_runtime}" == "docker" ]]; then
  archive_format="docker-archive"
fi
cid=""

cleanup() {
  if [[ -n "${cid}" ]]; then
    ${container_runtime} rm -f "${cid}" >/dev/null 2>&1 || true
  fi
  ${container_runtime} rmi -f "${image_name}:${image_tag}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

rm -rf "${work_root}"
mkdir -p "${log_dir}"

run_logged "${log_dir}/configure.log" cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=${container_runtime}"
run_logged "${log_dir}/build.log" cmake --build "${build_dir}"
if ! (cd "${build_dir}" && cpack -G External --verbose) >"${log_dir}/cpack.log" 2>&1; then
  cat "${log_dir}/cpack.log" >&2
  fail "Command failed: cpack -G External --verbose"
fi

archive_count=$(find "${build_dir}" -maxdepth 1 -type f -name "${image_name}-${image_tag}-*.tar" | wc -l | tr -d '[:space:]')
if [[ "${archive_count}" -ne 1 ]]; then
  find "${build_dir}" -maxdepth 5 -type f >"${work_root}/cpack-files.txt"
  fail "Expected exactly one top-level CPack-visible container archive, found ${archive_count}"
fi
archive_path="${build_dir}/${image_name}-${image_tag}-${archive_format}.tar"
assert_file "${archive_path}"
printf '%s\n' "${archive_path}" >"${work_root}/container-archive.txt"
grep -F "package: ${archive_path} generated" "${log_dir}/cpack.log" >/dev/null || fail "Expected CPack log to report the archive as the generated package"

${container_runtime} rmi -f "${image_name}:${image_tag}" >/dev/null 2>&1 || true
${container_runtime} load -i "${archive_path}" >"${work_root}/load.txt"

config_json="$(${container_runtime} inspect "${image_name}:${image_tag}" --format '{{json .Config}}')"
printf '%s\n' "${config_json}" >"${work_root}/image-config.json"
if grep -F '"User":"1000"' "${work_root}/image-config.json" >/dev/null; then
  fail "Image should not hard-code USER 1000 by default"
fi

cid="$(${container_runtime} create "${image_name}:${image_tag}")"

${container_runtime} export "${cid}" >"${work_root}/rootfs.tar"
tar -tf "${work_root}/rootfs.tar" >"${work_root}/rootfs.txt"

assert_contains "usr/local/bin/hello_container" "${work_root}/rootfs.txt"
assert_not_contains "Runtime/usr/local/bin/hello_container" "${work_root}/rootfs.txt"
assert_not_contains "Development/usr/local/share/cmake/minimal_container_example/minimal_container_exampleConfig.cmake" "${work_root}/rootfs.txt"
assert_not_contains "Dockerfile" "${work_root}/rootfs.txt"
assert_not_contains "Containerfile" "${work_root}/rootfs.txt"

${container_runtime} run --rm "${image_name}:${image_tag}" >"${work_root}/run.txt"
grep -F "Container test successful!" "${work_root}/run.txt" >/dev/null || fail "Expected example container to run successfully"

echo "[proof] Container flow proof passed. See ${work_root} for exported image evidence."
