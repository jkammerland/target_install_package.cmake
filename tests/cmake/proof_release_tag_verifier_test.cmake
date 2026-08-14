cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

find_program(_tip_bash bash)
if(NOT _tip_bash)
  _tip_proof_fail("bash is required for the release tag verifier proof")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/release-tag-verifier")
set(_tip_fake_bin_dir "${_tip_case_root}/fake-bin")
set(_tip_expected_fingerprint "7A9DA5E43CC1A9ECB9745CBE3A209DA2768BE08D")
set(_tip_other_fingerprint "1111222233334444555566667777888899990000")
set(_tip_tag_commit "0123456789ABCDEF0123456789ABCDEF01234567")
set(_tip_trusted_commit "89ABCDEF0123456789ABCDEF0123456789ABCDEF")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fake_bin_dir}")

file(
  WRITE "${_tip_fake_bin_dir}/gpg"
  "#!/bin/sh\n"
  "for arg in \"$@\"; do\n"
  "  if [ \"$arg\" = \"--fingerprint\" ]; then\n"
  "    printf 'fpr:::::::::%s:\\n' \"\${FAKE_PUBLIC_FINGERPRINT:-${_tip_expected_fingerprint}}\"\n"
  "    exit 0\n"
  "  fi\n"
  "done\n"
  "exit 0\n")

file(
  WRITE "${_tip_fake_bin_dir}/git"
  "#!/bin/sh\n"
  "command_name=\"$1\"\n"
  "shift\n"
  "case \"$command_name\" in\n"
  "  check-ref-format) exit 0 ;;\n"
  "  cat-file) printf '%s\\n' \"\${FAKE_TAG_TYPE:-tag}\" ;;\n"
  "  rev-parse)\n"
  "    case \"$*\" in\n"
  "      *refs/remotes/origin/master*) printf '%s\\n' '${_tip_trusted_commit}' ;;\n"
  "      *) printf '%s\\n' '${_tip_tag_commit}' ;;\n"
  "    esac\n"
  "    ;;\n"
  "  verify-tag)\n"
  "    if [ \"\${FAKE_VERIFY_FAIL:-0}\" = 1 ]; then printf '[GNUPG:] BADSIG fake\\n' >&2; exit 1; fi\n"
  "    printf '[GNUPG:] VALIDSIG %s 2026-01-01 0 4 0 19 10 00 %s\\n' \"\${FAKE_TAG_FINGERPRINT:-${_tip_expected_fingerprint}}\" \"\${FAKE_TAG_FINGERPRINT:-${_tip_expected_fingerprint}}\" >&2\n"
  "    ;;\n"
  "  rev-list) printf '%s\\n' '${_tip_tag_commit}' ;;\n"
  "  merge-base) [ \"\${FAKE_OFF_MASTER:-0}\" != 1 ] ;;\n"
  "  show)\n"
  "    printf 'cmake_minimum_required(VERSION 3.25)\\nproject(target_install_package VERSION %s LANGUAGES NONE)\\n' \"\${FAKE_PROJECT_VERSION:-7.0.7}\"\n"
  "    ;;\n"
  "  *) printf 'unexpected fake git command: %s %s\\n' \"$command_name\" \"$*\" >&2; exit 2 ;;\n"
  "esac\n")

file(
  CHMOD
  "${_tip_fake_bin_dir}/gpg"
  "${_tip_fake_bin_dir}/git"
  PERMISSIONS
  OWNER_READ
  OWNER_WRITE
  OWNER_EXECUTE
  GROUP_READ
  GROUP_EXECUTE
  WORLD_READ
  WORLD_EXECUTE)

set(_tip_verifier_command "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_bin_dir}:$ENV{PATH}" "${_tip_bash}" "${TIP_REPO_ROOT}/ci/run.sh" release verify-tag --tag v7.0.7 --trusted-ref
                          refs/remotes/origin/master)

_tip_proof_run_step(NAME "accepts-valid-release-tag" COMMAND ${_tip_verifier_command})

_tip_proof_expect_failure(
  NAME
  "rejects-lightweight-tag"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  "PATH=${_tip_fake_bin_dir}:$ENV{PATH}"
  FAKE_TAG_TYPE=commit
  "${_tip_bash}"
  "${TIP_REPO_ROOT}/ci/run.sh"
  release
  verify-tag
  --tag
  v7.0.7
  EXPECT_CONTAINS
  "must be an annotated tag")

_tip_proof_expect_failure(
  NAME
  "rejects-unexpected-signing-key"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  "PATH=${_tip_fake_bin_dir}:$ENV{PATH}"
  "FAKE_TAG_FINGERPRINT=${_tip_other_fingerprint}"
  "${_tip_bash}"
  "${TIP_REPO_ROOT}/ci/run.sh"
  release
  verify-tag
  --tag
  v7.0.7
  EXPECT_CONTAINS
  "was signed by")

_tip_proof_expect_failure(
  NAME
  "rejects-invalid-signature"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  "PATH=${_tip_fake_bin_dir}:$ENV{PATH}"
  FAKE_VERIFY_FAIL=1
  "${_tip_bash}"
  "${TIP_REPO_ROOT}/ci/run.sh"
  release
  verify-tag
  --tag
  v7.0.7
  EXPECT_CONTAINS
  "does not have a valid signature")

_tip_proof_expect_failure(
  NAME
  "rejects-tag-outside-master"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  "PATH=${_tip_fake_bin_dir}:$ENV{PATH}"
  FAKE_OFF_MASTER=1
  "${_tip_bash}"
  "${TIP_REPO_ROOT}/ci/run.sh"
  release
  verify-tag
  --tag
  v7.0.7
  EXPECT_CONTAINS
  "is not contained in")

_tip_proof_expect_failure(
  NAME
  "rejects-version-mismatch"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  "PATH=${_tip_fake_bin_dir}:$ENV{PATH}"
  FAKE_PROJECT_VERSION=9.9.9
  "${_tip_bash}"
  "${TIP_REPO_ROOT}/ci/run.sh"
  release
  verify-tag
  --tag
  v7.0.7
  EXPECT_CONTAINS
  "does not match project version")

_tip_proof_expect_failure(
  NAME
  "rejects-invalid-tag-name"
  COMMAND
  ${_tip_verifier_command}
  --tag
  release-7.0.7
  EXPECT_CONTAINS
  "must start with 'v'")

message(STATUS "[proof] Release tag verifier proof passed.")
