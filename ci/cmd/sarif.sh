#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ci/run.sh sarif [options]

Configures and generates the root project while retaining CMake diagnostics as
SARIF. The SARIF file is normalized after CMake exits, but CMake's original exit
status is preserved.

Options:
  --build-dir <dir>      Configure build directory (default: ./build/ci-sarif)
  --output <file>        SARIF output file (default: ./build/sarif/cmake-configure.sarif)
  --fmt-prefix <dir>     Prefix that contains fmt (default: ./build/ci-deps/fmt-install if present)
  --cmake-arg <arg>      Extra configure argument (repeatable)
  -h, --help             Show help
EOF
}

build_dir="${ci_root}/build/ci-sarif"
sarif_file="${ci_root}/build/sarif/cmake-configure.sarif"
fmt_prefix=""
cmake_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --build-dir)
      build_dir="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --output)
      sarif_file="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --fmt-prefix)
      fmt_prefix="$(ci_abs_path "${2:?}")"
      shift 2
      ;;
    --cmake-arg)
      cmake_args+=("${2:?}")
      shift 2
      ;;
    *)
      usage >&2
      ci_die "Unknown option: $1"
      ;;
  esac
done

ci_require_cmd cmake
ci_require_cmd ninja
ci_python_bin="$(ci_python)" || ci_die "python is required to validate and normalize SARIF output"

if [[ -z "${fmt_prefix}" ]]; then
  if [[ -d "${ci_root}/build/ci-deps/fmt-install" ]]; then
    fmt_prefix="${ci_root}/build/ci-deps/fmt-install"
  elif [[ -d "${ci_root}/fmt-install" ]]; then
    fmt_prefix="${ci_root}/fmt-install"
  fi
fi

mkdir -p "${build_dir}" "$(dirname "${sarif_file}")"

# Truncate the output before configuring so a failed rerun cannot publish stale diagnostics.
: >"${sarif_file}"
rm -f "${sarif_file}.invalid"

configure_args=(
  --log-level=DEBUG
  -S "$(ci_path_for_cmake "${ci_root}")"
  -B "$(ci_path_for_cmake "${build_dir}")"
  -G Ninja
  "--sarif-output=$(ci_path_for_cmake "${sarif_file}")"
  -DCMAKE_BUILD_TYPE=Release
  "-DCMAKE_INSTALL_PREFIX=$(ci_path_for_cmake "${build_dir}/install")"
  -DPROJECT_LOG_COLORS=ON
  -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON
  -Dtarget_install_package_BUILD_TESTS=ON
)
if [[ -n "${fmt_prefix}" ]]; then
  configure_args+=("-DCMAKE_PREFIX_PATH=$(ci_path_for_cmake "${fmt_prefix}")")
fi
configure_args+=("${cmake_args[@]}")

ci_log "==> Configure and generate CMake SARIF"
set +e
cmake "${configure_args[@]}"
configure_status=$?
set -e

normalization_summary="$("${ci_python_bin}" - "${sarif_file}" <<'PY'
import json
import sys
from pathlib import Path

sarif_path = Path(sys.argv[1])
fallback_reason = ""
contents = sarif_path.read_bytes() if sarif_path.is_file() else b""

if not contents.strip():
    fallback_reason = "CMake produced no SARIF content"
    document = None
else:
    try:
        document = json.loads(contents)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fallback_reason = f"CMake produced malformed SARIF: {error}"
        document = None


def is_sarif_21(value):
    if not isinstance(value, dict) or value.get("version") != "2.1.0":
        return False
    runs = value.get("runs")
    if not isinstance(runs, list) or not runs:
        return False
    for run in runs:
        if not isinstance(run, dict) or not isinstance(run.get("results", []), list):
            return False
        tool = run.get("tool")
        driver = tool.get("driver") if isinstance(tool, dict) else None
        if not isinstance(driver, dict) or not isinstance(driver.get("name"), str) or not driver["name"]:
            return False
    return True


if document is not None and not is_sarif_21(document):
    fallback_reason = "CMake produced JSON that is not SARIF 2.1.0"
    document = None

if document is None:
    if contents.strip():
        sarif_path.with_name(f"{sarif_path.name}.invalid").write_bytes(contents)
    document = {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "CMake",
                        "informationUri": "https://cmake.org",
                        "rules": [],
                    }
                },
                "results": [],
            }
        ],
    }
    sarif_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")

result_count = sum(len(run.get("results", [])) for run in document["runs"])
if fallback_reason:
    print(f"warning: {fallback_reason}; wrote valid empty SARIF to {sarif_path}")
else:
    print(f"SARIF valid: {sarif_path} ({result_count} result(s))")
PY
)"
ci_log "${normalization_summary}"

if ((configure_status != 0)); then
  ci_warn "CMake configure/generate failed with status ${configure_status}; SARIF was retained at ${sarif_file}"
fi
exit "${configure_status}"
