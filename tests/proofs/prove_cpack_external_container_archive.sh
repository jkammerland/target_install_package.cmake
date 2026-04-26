#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"

fail() {
  echo "[proof] $*" >&2
  exit 1
}

rm -rf "${work_root}"
mkdir -p "${work_root}/wrappers" "${work_root}/logs"
mkdir -p "${work_root}/ccache"
export CCACHE_DIR="${work_root}/ccache"

cat >"${work_root}/wrappers/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  build)
    context="${@: -1}"
    if [ -f "$context/usr/local/bin/hello_container" ]; then
      :
    elif [ -f "$context/usr/local/bin/relative_app" ] && [ -f "$context/etc/proof/relative-overlay.txt" ]; then
      :
    else
      exit 41
    fi
    ;;
  save)
    shift
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -o)
          printf 'archive\n' >"$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    ;;
  images)
    printf '1 MB\n'
    ;;
  *)
    echo "unexpected podman command: $*" >&2
    exit 99
    ;;
esac
EOF

chmod +x "${work_root}/wrappers/podman"

image_name="tip-proof-cpack-archive"
image_tag="1.0.0"
build_dir="${work_root}/build"

if cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${work_root}/bad-name-build" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=Bad Image Name" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  >"${work_root}/logs/bad-name-configure.log" 2>&1; then
  fail "Expected invalid container image name to fail at configure time"
fi
grep -F "CONTAINER_NAME" "${work_root}/logs/bad-name-configure.log" >/dev/null || fail "Expected invalid image name diagnostic"

if cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${work_root}/tagged-name-build" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}:dev" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  >"${work_root}/logs/tagged-name-configure.log" 2>&1; then
  fail "Expected tagged container image name to fail at configure time"
fi
grep -F "Use CONTAINER_TAG instead" "${work_root}/logs/tagged-name-configure.log" >/dev/null || fail "Expected tagged image name diagnostic"

if cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${work_root}/bad-tag-build" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=bad tag" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  >"${work_root}/logs/bad-tag-configure.log" 2>&1; then
  fail "Expected invalid container image tag to fail at configure time"
fi
grep -F "CONTAINER_TAG" "${work_root}/logs/bad-tag-configure.log" >/dev/null || fail "Expected invalid image tag diagnostic"

if cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${work_root}/bad-archive-format-build" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  "-DMINIMAL_CONTAINER_ARCHIVE_FORMAT=invalid-format" \
  >"${work_root}/logs/bad-archive-format-configure.log" 2>&1; then
  fail "Expected invalid container archive format to fail at configure time"
fi
grep -F "CONTAINER_ARCHIVE_FORMAT" "${work_root}/logs/bad-archive-format-configure.log" >/dev/null || fail "Expected invalid archive format diagnostic"

if cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${work_root}/bad-component-build" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  "-DMINIMAL_CONTAINER_COMPONENTS=MissingComponent" \
  >"${work_root}/logs/bad-component-configure.log" 2>&1; then
  fail "Expected unknown container component to fail at configure time"
fi
grep -F "unknown component 'MissingComponent'" "${work_root}/logs/bad-component-configure.log" >/dev/null || fail "Expected unknown component diagnostic"

cmake \
  -S "${repo_root}/examples/minimal-container" \
  -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  "-DMINIMAL_CONTAINER_IMAGE_NAME=${image_name}" \
  "-DMINIMAL_CONTAINER_IMAGE_TAG=${image_tag}" \
  "-DMINIMAL_CONTAINER_RUNTIME=podman" \
  >"${work_root}/logs/configure.log" 2>&1

cmake --build "${build_dir}" >"${work_root}/logs/build.log" 2>&1
(cd "${build_dir}" && PATH="${work_root}/wrappers:$PATH" cpack -G External --verbose) >"${work_root}/logs/cpack.log" 2>&1

archive_path="${build_dir}/${image_name}-${image_tag}-oci-archive.tar"
[[ -f "${archive_path}" ]] || fail "Expected CPack to publish archive at top level: ${archive_path}"

internal_archive_count=$(find "${build_dir}/_CPack_Packages" -type f -name "${image_name}-${image_tag}-oci-archive.tar" 2>/dev/null | wc -l | tr -d '[:space:]')
[[ "${internal_archive_count}" -eq 1 ]] || fail "Expected exactly one internal staging archive before CPack copy"

top_archive_count=$(find "${build_dir}" -maxdepth 1 -type f -name "${image_name}-${image_tag}-*.tar" | wc -l | tr -d '[:space:]')
[[ "${top_archive_count}" -eq 1 ]] || fail "Expected exactly one top-level CPack archive, found ${top_archive_count}"

if grep -F "package: ${build_dir}/${image_name}-${image_tag}-oci-archive.tar generated" "${work_root}/logs/cpack.log" >/dev/null; then
  :
else
  cat "${work_root}/logs/cpack.log" >&2
  fail "Expected CPack log to report the archive as the generated package"
fi

relative_src="${work_root}/relative-overlay-src"
relative_build="${work_root}/relative-overlay-build"
mkdir -p "${relative_src}/app/src" "${relative_src}/app/rootfs-overlay/etc/proof"
cat >"${relative_src}/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.25)
project(relative_overlay_parent LANGUAGES CXX)
add_subdirectory(app)
EOF
cat >"${relative_src}/app/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.25)
project(relative_overlay_fixture VERSION 1.0.0 LANGUAGES CXX)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include("${repo_root}/cmake/load_target_install_package.cmake")
add_executable(relative_app src/main.cpp)
target_compile_features(relative_app PRIVATE cxx_std_17)
target_install_package(relative_app EXPORT_NAME \${PROJECT_NAME})
include("${repo_root}/export_cpack.cmake")
export_cpack(
  PACKAGE_NAME "\${PROJECT_NAME}"
  PACKAGE_VERSION "\${PROJECT_VERSION}"
  GENERATORS "CONTAINER"
  CONTAINER_NAME "relative-overlay-proof"
  CONTAINER_TAG "\${PROJECT_VERSION}"
  CONTAINER_RUNTIME "podman"
  CONTAINER_ENTRYPOINT "/usr/local/bin/relative_app"
  CONTAINER_ROOTFS_OVERLAYS rootfs-overlay)
EOF
printf '#include <iostream>\nint main() { std::cout << "relative overlay proof\\\\n"; return 0; }\n' >"${relative_src}/app/src/main.cpp"
printf 'relative overlay\n' >"${relative_src}/app/rootfs-overlay/etc/proof/relative-overlay.txt"

cmake -S "${relative_src}" -B "${relative_build}" -DCMAKE_BUILD_TYPE=Release >"${work_root}/logs/relative-configure.log" 2>&1
cmake --build "${relative_build}" >"${work_root}/logs/relative-build.log" 2>&1
(cd "${relative_build}" && PATH="${work_root}/wrappers:$PATH" cpack -G External --verbose) >"${work_root}/logs/relative-cpack.log" 2>&1
[[ -f "${relative_build}/relative-overlay-proof-1.0.0-oci-archive.tar" ]] || fail "Expected relative overlay fixture archive"

echo "[proof] CPack External container archive proof passed."
