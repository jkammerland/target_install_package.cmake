#!/usr/bin/env bash
set -euo pipefail

ci_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ci_root}/ci/lib/common.sh"

readonly release_signing_fingerprint="7A9DA5E43CC1A9ECB9745CBE3A209DA2768BE08D"

usage() {
  cat <<'EOF'
Usage: ci/run.sh release verify-tag --tag <tag> [options]

Options:
  --tag <tag>               Annotated release tag to verify
  --trusted-ref <ref>       Ref that must contain the tagged commit (default: refs/remotes/origin/master)
  --public-key <path>       Trusted release public key (default: .github/release-signing-key.asc)
EOF
}

verify_tag() {
  local tag=""
  local trusted_ref="refs/remotes/origin/master"
  local public_key="${ci_root}/.github/release-signing-key.asc"

  while (($#)); do
    case "$1" in
      --tag)
        [[ $# -ge 2 ]] || ci_die "--tag requires a value"
        tag="$2"
        shift 2
        ;;
      --trusted-ref)
        [[ $# -ge 2 ]] || ci_die "--trusted-ref requires a value"
        trusted_ref="$2"
        shift 2
        ;;
      --public-key)
        [[ $# -ge 2 ]] || ci_die "--public-key requires a value"
        public_key="$2"
        shift 2
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *) ci_die "Unknown release verify-tag option: $1" ;;
    esac
  done

  [[ -n "${tag}" ]] || ci_die "--tag is required"
  [[ "${tag}" == v* ]] || ci_die "Release tag must start with 'v': ${tag}"
  git check-ref-format "refs/tags/${tag}" >/dev/null || ci_die "Invalid release tag: ${tag}"

  local tag_ref="refs/tags/${tag}"
  local tag_type
  tag_type="$(git cat-file -t "${tag_ref}" 2>/dev/null || true)"
  [[ "${tag_type}" == "tag" ]] || ci_die "Release tag ${tag} must be an annotated tag; got ${tag_type:-missing}"
  git rev-parse --verify --quiet "${trusted_ref}^{commit}" >/dev/null || ci_die "Trusted ref does not resolve to a commit: ${trusted_ref}"
  [[ -f "${public_key}" ]] || ci_die "Release public key not found: ${public_key}"

  local gnupg_home
  gnupg_home="$(mktemp -d)"
  chmod 700 "${gnupg_home}"
  trap 'rm -rf "${gnupg_home}"' RETURN

  GNUPGHOME="${gnupg_home}" gpg --batch --quiet --no-autostart --import "${public_key}"

  local imported_fingerprint
  imported_fingerprint="$(GNUPGHOME="${gnupg_home}" gpg --batch --no-autostart --with-colons --fingerprint | awk -F: '/^fpr:/ { print toupper($10); exit }')"
  [[ "${imported_fingerprint}" == "${release_signing_fingerprint}" ]] || ci_die "Release public key fingerprint is ${imported_fingerprint:-missing}, expected ${release_signing_fingerprint}"

  local verification_output
  if ! verification_output="$(GNUPGHOME="${gnupg_home}" git verify-tag --raw "${tag_ref}" 2>&1)"; then
    printf '%s\n' "${verification_output}" >&2
    ci_die "Release tag ${tag} does not have a valid signature"
  fi

  local tag_fingerprint
  tag_fingerprint="$(awk '/^\[GNUPG:\] VALIDSIG / { print toupper($3); exit }' <<<"${verification_output}")"
  [[ "${tag_fingerprint}" == "${release_signing_fingerprint}" ]] || ci_die "Release tag ${tag} was signed by ${tag_fingerprint:-unknown}, expected ${release_signing_fingerprint}"

  local tag_commit trusted_commit
  tag_commit="$(git rev-list -n 1 "${tag_ref}")"
  trusted_commit="$(git rev-parse "${trusted_ref}^{commit}")"
  git merge-base --is-ancestor "${tag_commit}" "${trusted_commit}" || ci_die "Release tag ${tag} commit ${tag_commit} is not contained in ${trusted_ref}"

  local python_bin project_version tag_version
  python_bin="$(ci_python)" || ci_die "Python is required to read the project version"
  project_version="$({ git show "${tag_commit}:CMakeLists.txt" || exit 1; } | "${python_bin}" -c '
import re
import sys

text = sys.stdin.read()
project = re.search(r"project\s*\(\s*target_install_package\b(?P<body>.*?)\)", text, re.S)
if not project:
    raise SystemExit("Could not find target_install_package project declaration")
version = re.search(r"\bVERSION\s+([^\s\)]+)", project.group("body"))
if not version:
    raise SystemExit("Could not find target_install_package project version")
print(version.group(1))
')"
  tag_version="${tag#v}"
  [[ "${tag_version}" == "${project_version}" ]] || ci_die "Release tag ${tag} does not match project version ${project_version}"

  printf 'release_tag=%s\n' "${tag}"
  printf 'release_commit=%s\n' "${tag_commit}"
  printf 'release_version=%s\n' "${project_version}"
}

subcommand="${1:-}"
case "${subcommand}" in
  verify-tag)
    shift
    verify_tag "$@"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    usage >&2
    ci_die "Unknown release subcommand: ${subcommand}"
    ;;
esac
