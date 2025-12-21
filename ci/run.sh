#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ci_dir="${ci_root}/ci"

# shellcheck disable=SC1091
source "${ci_dir}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ci/run.sh <subcommand> [options]

Subcommands:
  bootstrap         Install/prepare CI dependencies (OS-aware)
  main              Configure/build/test/install root project via presets
  consumer          Build/run consumer tests
  examples          Configure/build/test examples via examples/CMakePresets.json
  cpack             Run CPack integration/smoke workflows
  packaging-tests   Run packaging tests under tests/packaging

Run `ci/run.sh <subcommand> --help` for subcommand options.
EOF
}

subcommand="${1:-}"
case "${subcommand}" in
  ""|-h|--help|help)
    usage
    exit 0
    ;;
  bootstrap|main|consumer|examples|cpack|packaging-tests)
    shift
    exec bash "${ci_dir}/cmd/${subcommand}.sh" "$@"
    ;;
  *)
    usage >&2
    ci_die "Unknown subcommand: ${subcommand}"
    ;;
esac
