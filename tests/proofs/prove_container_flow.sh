#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"

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

runtime=""
if command -v podman >/dev/null 2>&1; then
  runtime="podman"
elif command -v docker >/dev/null 2>&1; then
  runtime="docker"
else
  fail "Neither podman nor docker is available"
fi

build_dir="${work_root}/build"
log_dir="${work_root}/logs"

rm -rf "${work_root}"
mkdir -p "${log_dir}"

cmake -S "${repo_root}/examples/minimal-container" -B "${build_dir}" -DCMAKE_BUILD_TYPE=Release >"${log_dir}/configure.log" 2>&1
cmake --build "${build_dir}" >"${log_dir}/build.log" 2>&1
(cd "${build_dir}" && cpack -G External --verbose) >"${log_dir}/cpack.log" 2>&1

json_pkg="${build_dir}/minimal_container_example-1.0.0-Linux.json"
assert_file "${json_pkg}"

config_json="$(${runtime} inspect hello:1.0.0 --format '{{json .Config}}')"
printf '%s\n' "${config_json}" >"${work_root}/image-config.json"
if grep -F '"User":"1000"' "${work_root}/image-config.json" >/dev/null; then
  fail "Image should not hard-code USER 1000 by default"
fi

cid="$(${runtime} create hello:1.0.0)"
cleanup() {
  ${runtime} rm -f "${cid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

${runtime} export "${cid}" >"${work_root}/rootfs.tar"
tar -tf "${work_root}/rootfs.tar" >"${work_root}/rootfs.txt"

assert_contains "usr/local/bin/hello_container" "${work_root}/rootfs.txt"
assert_not_contains "Runtime/usr/local/bin/hello_container" "${work_root}/rootfs.txt"
assert_not_contains "Development/usr/local/share/cmake/minimal_container_example/minimal_container_exampleConfig.cmake" "${work_root}/rootfs.txt"
assert_not_contains "Dockerfile" "${work_root}/rootfs.txt"

${runtime} run --rm hello:1.0.0 >"${work_root}/run.txt"
grep -F "Container test successful!" "${work_root}/run.txt" >/dev/null || fail "Expected example container to run successfully"

echo "[proof] Container flow proof passed. See ${work_root} for exported image evidence."
