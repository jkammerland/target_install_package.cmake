#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:?repo root required}"
work_root="${2:?work root required}"
python_bin="${3:?python command required}"

fail() {
  printf '[proof] %s\n' "$*" >&2
  exit 1
}

rm -rf "${work_root}"
mkdir -p "${work_root}/bin" "${work_root}/fmt"

cat >"${work_root}/bin/cmake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
printf '%s\n' "$@" >"${FAKE_CMAKE_LOG:?}"
for argument in "$@"; do
  case "${argument}" in
    --sarif-output=*) output="${argument#*=}" ;;
  esac
done
[[ -n "${output}" ]] || exit 97
mkdir -p "$(dirname "${output}")"

case "${FAKE_CMAKE_MODE:?}" in
  valid|valid-failure)
    cat >"${output}" <<'JSON'
{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"Fake CMake","rules":[]}},"results":[{"level":"warning","message":{"text":"proof warning"},"ruleId":"Proof.Warning"}]}]}
JSON
    ;;
  empty-success|empty-failure)
    : >"${output}"
    ;;
  malformed)
    printf '{not json\n' >"${output}"
    ;;
  non-sarif)
    printf '{"version":"2.0.0","runs":[]}\n' >"${output}"
    ;;
  *) exit 96 ;;
esac

case "${FAKE_CMAKE_MODE}" in
  valid-failure) exit 23 ;;
  empty-failure) exit 42 ;;
  *) exit 0 ;;
esac
EOF

cat >"${work_root}/bin/ninja" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${work_root}/bin/cmake" "${work_root}/bin/ninja"

validate_sarif() {
  local path="${1:?}"
  local expected_tool="${2:?}"
  local expected_results="${3:?}"
  "${python_bin}" - "${path}" "${expected_tool}" "${expected_results}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
assert document["version"] == "2.1.0"
assert isinstance(document["runs"], list) and document["runs"]
assert document["runs"][0]["tool"]["driver"]["name"] == sys.argv[2]
assert len(document["runs"][0]["results"]) == int(sys.argv[3])
PY
}

run_case() {
  local mode="${1:?}"
  local expected_status="${2:?}"
  local expected_tool="${3:?}"
  local expected_results="${4:?}"
  local case_root="${work_root}/${mode}"
  local output="${case_root}/out/cmake.sarif"
  local build_dir="${case_root}/build with spaces"

  mkdir -p "${case_root}"
  set +e
  FAKE_CMAKE_MODE="${mode}" \
    FAKE_CMAKE_LOG="${case_root}/arguments.log" \
    PATH="${work_root}/bin:${PATH}" \
    bash "${repo_root}/ci/run.sh" sarif \
      --build-dir "${build_dir}" \
      --output "${output}" \
      --fmt-prefix "${work_root}/fmt" \
      >"${case_root}/runner.log" 2>&1
  actual_status=$?
  set -e

  [[ "${actual_status}" -eq "${expected_status}" ]] || {
    cat "${case_root}/runner.log" >&2
    fail "${mode}: expected status ${expected_status}, got ${actual_status}"
  }
  validate_sarif "${output}" "${expected_tool}" "${expected_results}"
  grep -Fx -- "--sarif-output=${output}" "${case_root}/arguments.log" >/dev/null || fail "${mode}: SARIF output argument was not forwarded"
  grep -Fx -- "${build_dir}" "${case_root}/arguments.log" >/dev/null || fail "${mode}: build directory was not forwarded"
}

run_case valid 0 "Fake CMake" 1
run_case valid-failure 23 "Fake CMake" 1
run_case empty-success 0 CMake 0
run_case empty-failure 42 CMake 0
run_case malformed 0 CMake 0
run_case non-sarif 0 CMake 0

[[ -s "${work_root}/malformed/out/cmake.sarif.invalid" ]] || fail "malformed: raw invalid output was not retained"
grep -F '{not json' "${work_root}/malformed/out/cmake.sarif.invalid" >/dev/null || fail "malformed: retained raw output changed"
[[ -s "${work_root}/non-sarif/out/cmake.sarif.invalid" ]] || fail "non-sarif: raw invalid output was not retained"
grep -F '"version":"2.0.0"' "${work_root}/non-sarif/out/cmake.sarif.invalid" >/dev/null || fail "non-sarif: retained raw output changed"

printf '%s\n' "[proof] CMake SARIF runner proof passed."
