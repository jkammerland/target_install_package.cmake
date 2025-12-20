#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

base_install="${ci_root}/examples/basic-shared/build/install"

if [[ ! -d "${base_install}" ]]; then
  ci_die "Expected install dir not found: ${base_install}"
fi

config_dirs=(
  "${base_install}"
  "${base_install}/Debug"
  "${base_install}/Release"
  "${base_install}/MinSizeRel"
  "${base_install}/RelWithDebInfo"
  "${base_install}/debug"
  "${base_install}/release"
  "${base_install}/minsizerel"
  "${base_install}/relwithdebinfo"
)

find_first_library() {
  local search_root="$1"
  shift

  if [[ ! -d "${search_root}" ]]; then
    return 1
  fi

  local pattern result
  for pattern in "$@"; do
    result="$(find "${search_root}" \( -type f -o -type l \) -name "${pattern}" -print -quit 2>/dev/null || true)"
    if [[ -n "${result}" ]]; then
      printf '%s\n' "${result}"
      return 0
    fi
  done

  return 1
}

debug_patterns=("libstring_utilsd.so" "libstring_utilsd.so.*" "libstring_utilsd.dylib" "libstring_utilsd.dylib.*" "string_utilsd.dll" "string_utilsd.lib")
release_patterns=("libstring_utils.so" "libstring_utils.so.*" "libstring_utils.dylib" "libstring_utils.dylib.*" "string_utils.dll" "string_utils.lib")

has_debug_lib=false
debug_location=""
for dir in "${config_dirs[@]}"; do
  if debug_location="$(find_first_library "${dir}" "${debug_patterns[@]}")"; then
    has_debug_lib=true
    break
  fi
done

if [[ "${has_debug_lib}" == "true" ]]; then
  ci_log "✓ Debug library with postfix found at: ${debug_location}"
else
  ci_log "✗ Debug library with postfix NOT found"
  find "${base_install}" -name "*string_utils*" || true
  exit 1
fi

has_release_lib=false
release_location=""
for dir in "${config_dirs[@]}"; do
  if release_location="$(find_first_library "${dir}" "${release_patterns[@]}")"; then
    has_release_lib=true
    break
  fi
done

if [[ "${has_release_lib}" == "true" ]]; then
  ci_log "✓ Release library found at: ${release_location}"
else
  ci_log "✗ Release library NOT found"
  find "${base_install}" -name "*string_utils*" || true
  exit 1
fi

ci_log "Checking for configuration-specific CMake files..."
config_files_found=0
for config in debug release minsizerel relwithdebinfo; do
  for dir in "${config_dirs[@]}"; do
    cmake_path="${dir}/share/cmake/string_utils/string_utils-${config}.cmake"
    if [[ -f "${cmake_path}" ]]; then
      ci_log "✓ Found string_utils-${config}.cmake in ${dir}"
      config_files_found=$((config_files_found + 1))
      break
    fi
  done
done

if [[ "${config_files_found}" -ge 3 ]]; then
  ci_log "✓ Found ${config_files_found} configuration-specific CMake files"
else
  ci_log "✗ Expected at least 3 configuration-specific CMake files, found ${config_files_found}"
  find "${base_install}" -path "*share/cmake*" -name "*.cmake" || true
  exit 1
fi

ci_log "✓ Multi-config artifacts verification completed successfully"

