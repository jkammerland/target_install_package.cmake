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
  _tip_proof_fail("bash is required for signed package verifier proof")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/signed-verifier-key")
set(_tip_fake_bin_dir "${_tip_case_root}/fake-bin")
set(_tip_package_dir "${_tip_case_root}/packages")
set(_tip_expired_package_dir "${_tip_case_root}/expired-packages")
set(_tip_verifier_dir "${_tip_case_root}/verifier")
set(_tip_good_fingerprint "AAAABBBBCCCCDDDDEEEEFFFF1111222233334444")
set(_tip_good_subkey_fingerprint "1234567890ABCDEF1234567890ABCDEF12345678")
set(_tip_other_fingerprint "9999888877776666555544443333222211110000")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fake_bin_dir}")
file(MAKE_DIRECTORY "${_tip_package_dir}")
file(MAKE_DIRECTORY "${_tip_expired_package_dir}")
file(MAKE_DIRECTORY "${_tip_verifier_dir}")

file(
  WRITE "${_tip_fake_bin_dir}/gpg"
  "#!/bin/sh\n"
  "list_keys=false\n"
  "recv_keys=false\n"
  "verify_signature=false\n"
  "status_fd=''\n"
  "status_fd_next=false\n"
  "last_arg=''\n"
  "for arg in \"$@\"; do\n"
  "  if [ \"$status_fd_next\" = true ]; then\n"
  "    status_fd=\"$arg\"\n"
  "    status_fd_next=false\n"
  "    last_arg=\"$arg\"\n"
  "    continue\n"
  "  fi\n"
  "  case \"$arg\" in\n"
  "    --list-keys) list_keys=true ;;\n"
  "    --recv-keys) recv_keys=true ;;\n"
  "    --verify) verify_signature=true ;;\n"
  "    --status-fd) status_fd_next=true ;;\n"
  "    --status-fd=*) status_fd=$(printf '%s' \"$arg\" | sed 's/^--status-fd=//') ;;\n"
  "  esac\n"
  "  last_arg=\"$arg\"\n"
  "done\n"
  "if [ \"$recv_keys\" = true ]; then exit 0; fi\n"
  "if [ \"$list_keys\" = true ]; then\n"
  "  case \"$last_arg\" in\n"
  "    *GOODKEY*|*33334444*) printf 'fpr:::::::::${_tip_good_fingerprint}:\\n' ;;\n"
  "    *) printf 'fpr:::::::::${_tip_other_fingerprint}:\\n' ;;\n"
  "  esac\n"
  "  exit 0\n"
  "fi\n"
  "if [ \"$verify_signature\" = true ]; then\n"
  "  if [ \"$status_fd\" != '1' ]; then exit 0; fi\n"
  "  actual_fingerprint='${_tip_good_subkey_fingerprint}'\n"
  "  primary_fingerprint='${_tip_good_fingerprint}'\n"
  "  case \"$last_arg\" in\n"
  "    *wrong*) actual_fingerprint='${_tip_other_fingerprint}'; primary_fingerprint='${_tip_other_fingerprint}' ;;\n"
  "  esac\n"
  "  case \"$last_arg\" in\n"
  "    *expired*) printf '[GNUPG:] EXPKEYSIG %s Expired Key\\n' \"$actual_fingerprint\" ;;\n"
  "  esac\n"
  "  printf '[GNUPG:] VALIDSIG %s 2026-01-01 0 4 0 1 10 00 %s\\n' \"$actual_fingerprint\" \"$primary_fingerprint\"\n"
  "  exit 0\n"
  "fi\n"
  "exit 0\n")

file(
  CHMOD
  "${_tip_fake_bin_dir}/gpg"
  PERMISSIONS
  OWNER_READ
  OWNER_WRITE
  OWNER_EXECUTE
  GROUP_READ
  GROUP_EXECUTE
  WORLD_READ
  WORLD_EXECUTE)

set(PROJECT_NAME ProofVerifier)
set(PROJECT_VERSION 1.0.0)
set(GPG_SIGNING_KEY GOODKEY)
set(GPG_KEYSERVER hkps://keys.example.invalid)
set(GENERATE_CHECKSUMS OFF)
configure_file("${TIP_REPO_ROOT}/examples/cpack-signed/verify_template.sh.in" "${_tip_verifier_dir}/verify.sh" @ONLY)

file(
  CHMOD
  "${_tip_verifier_dir}/verify.sh"
  PERMISSIONS
  OWNER_READ
  OWNER_WRITE
  OWNER_EXECUTE
  GROUP_READ
  GROUP_EXECUTE
  WORLD_READ
  WORLD_EXECUTE)

file(WRITE "${_tip_package_dir}/proof.tar.gz" "package\n")
file(WRITE "${_tip_package_dir}/proof.tar.gz.sig" "signature\n")
file(WRITE "${_tip_expired_package_dir}/expired.tar.gz" "package\n")
file(WRITE "${_tip_expired_package_dir}/expired.tar.gz.sig" "signature\n")

set(_tip_verifier_env "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_bin_dir}:$ENV{PATH}")

_tip_proof_run_step(
  NAME
  "verifier-accepts-expected-primary-long-key-id"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  1111222233334444
  --min-packages
  1)

_tip_proof_run_step(
  NAME
  "verifier-accepts-expected-signing-subkey-long-key-id"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  90ABCDEF12345678
  --min-packages
  1)

_tip_proof_expect_failure(
  NAME
  "verifier-rejects-keyring-resolved-selector"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  GOODKEY
  --min-packages
  1
  EXPECT_CONTAINS
  "full fingerprint or 16-hex long key ID")

_tip_proof_expect_failure(
  NAME
  "verifier-rejects-unexpected-signing-key"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  9999888877776666
  --min-packages
  1
  EXPECT_CONTAINS
  "GPG signer mismatch")

_tip_proof_expect_failure(
  NAME
  "verifier-rejects-short-fingerprint-suffix"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  33334444
  --min-packages
  1
  EXPECT_CONTAINS
  "full fingerprint or 16-hex long key ID")

file(WRITE "${_tip_package_dir}/proof-wrong.tar.gz" "package\n")
file(WRITE "${_tip_package_dir}/proof-wrong.tar.gz.sig" "signature\n")

_tip_proof_expect_failure(
  NAME
  "verifier-rejects-any-mismatch-even-after-minimum-success"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_package_dir}"
  --package-types
  tar.gz
  --key-id
  1111222233334444
  --min-packages
  1
  EXPECT_CONTAINS
  "GPG signer mismatch")

_tip_proof_expect_failure(
  NAME
  "verifier-rejects-expired-signature-status"
  COMMAND
  ${_tip_verifier_env}
  "${_tip_bash}"
  "${_tip_verifier_dir}/verify.sh"
  --directory
  "${_tip_expired_package_dir}"
  --package-types
  tar.gz
  --key-id
  1111222233334444
  --min-packages
  1
  EXPECT_CONTAINS
  "EXPKEYSIG")

message(STATUS "[proof] Signed verifier key proof passed.")
