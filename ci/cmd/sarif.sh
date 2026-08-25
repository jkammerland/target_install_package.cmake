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
SARIF. The SARIF file is normalized after CMake exits. CMake failures preserve
their original status; invalid output also fails an otherwise successful run.

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

set +e
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


def component_error(component, path):
    if not isinstance(component, dict):
        return f"{path} must be an object"
    if not isinstance(component.get("name"), str) or not component["name"]:
        return f"{path}.name must be a non-empty string"

    rules = component.get("rules", [])
    if not isinstance(rules, list):
        return f"{path}.rules must be an array"
    for rule_index, rule in enumerate(rules):
        rule_path = f"{path}.rules[{rule_index}]"
        if not isinstance(rule, dict):
            return f"{rule_path} must be an object"
        if not isinstance(rule.get("id"), str) or not rule["id"]:
            return f"{rule_path}.id must be a non-empty string"
        if "name" in rule and not isinstance(rule["name"], str):
            return f"{rule_path}.name must be a string"
    return None


def sarif_21_error(value):
    if not isinstance(value, dict):
        return "the document must be an object"
    if value.get("version") != "2.1.0":
        return "version must be 2.1.0"
    runs = value.get("runs")
    if not isinstance(runs, list) or not runs:
        return "runs must be a non-empty array"

    for run_index, run in enumerate(runs):
        run_path = f"runs[{run_index}]"
        if not isinstance(run, dict):
            return f"{run_path} must be an object"
        tool = run.get("tool")
        if not isinstance(tool, dict):
            return f"{run_path}.tool must be an object"
        driver = tool.get("driver")
        error = component_error(driver, f"{run_path}.tool.driver")
        if error:
            return error

        extensions = tool.get("extensions", [])
        if not isinstance(extensions, list):
            return f"{run_path}.tool.extensions must be an array"
        for extension_index, extension in enumerate(extensions):
            error = component_error(extension, f"{run_path}.tool.extensions[{extension_index}]")
            if error:
                return error

        results = run.get("results", [])
        if not isinstance(results, list):
            return f"{run_path}.results must be an array"
        rules = driver.get("rules", [])
        for result_index, result in enumerate(results):
            result_path = f"{run_path}.results[{result_index}]"
            if not isinstance(result, dict):
                return f"{result_path} must be an object"
            message = result.get("message")
            if not isinstance(message, dict):
                return f"{result_path}.message must be an object"
            if not isinstance(message.get("text"), str) or not message["text"]:
                return f"{result_path}.message.text must be a non-empty string"

            rule_id = result.get("ruleId")
            if rule_id is not None and (not isinstance(rule_id, str) or not rule_id):
                return f"{result_path}.ruleId must be a non-empty string"
            rule_index_value = result.get("ruleIndex")
            if rule_index_value is not None:
                if isinstance(rule_index_value, bool) or not isinstance(rule_index_value, int) or rule_index_value < 0 or rule_index_value >= len(rules):
                    return f"{result_path}.ruleIndex must identify a driver rule"
                indexed_rule_id = rules[rule_index_value]["id"]
                if rule_id is not None and rule_id != indexed_rule_id:
                    return f"{result_path}.ruleId must match the indexed driver rule"

            level = result.get("level")
            if level is not None and level not in {"none", "note", "warning", "error"}:
                return f"{result_path}.level is not a SARIF level"
    return None


if document is not None:
    validation_error = sarif_21_error(document)
    if validation_error:
        fallback_reason = f"CMake produced invalid SARIF 2.1.0: {validation_error}"
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

if fallback_reason:
    raise SystemExit(1)
PY
)"
normalization_status=$?
set -e
ci_log "${normalization_summary}"

if ((configure_status != 0)); then
  ci_warn "CMake configure/generate failed with status ${configure_status}; SARIF was retained at ${sarif_file}"
  exit "${configure_status}"
fi

if ((normalization_status != 0)); then
  ci_warn "CMake configure/generate succeeded, but its SARIF output was invalid; failing after retaining diagnostics at ${sarif_file}"
  exit 1
fi
