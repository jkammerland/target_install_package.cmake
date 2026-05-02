cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/gpg-signing-methods")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")
set(_tip_no_rpm_source_dir "${_tip_case_root}/no-rpm-source")
set(_tip_no_rpm_build_dir "${_tip_case_root}/no-rpm-build")
set(_tip_mixed_embedded_source_dir "${_tip_case_root}/mixed-embedded-source")
set(_tip_mixed_embedded_build_dir "${_tip_case_root}/mixed-embedded-build")
set(_tip_both_no_rpm_source_dir "${_tip_case_root}/both-no-rpm-source")
set(_tip_both_no_rpm_build_dir "${_tip_case_root}/both-no-rpm-build")
set(_tip_checksums_off_source_dir "${_tip_case_root}/checksums-off-source")
set(_tip_checksums_off_build_dir "${_tip_case_root}/checksums-off-build")
set(_tip_checksums_only_source_dir "${_tip_case_root}/checksums-only-source")
set(_tip_checksums_only_build_dir "${_tip_case_root}/checksums-only-build")
set(_tip_invalid_signing_method_source_dir "${_tip_case_root}/invalid-signing-method-source")
set(_tip_invalid_signing_method_build_dir "${_tip_case_root}/invalid-signing-method-build")
set(_tip_invalid_checksums_source_dir "${_tip_case_root}/invalid-checksums-source")
set(_tip_invalid_checksums_build_dir "${_tip_case_root}/invalid-checksums-build")
set(_tip_explicit_sign_no_key_source_dir "${_tip_case_root}/explicit-sign-no-key-source")
set(_tip_explicit_sign_no_key_build_dir "${_tip_case_root}/explicit-sign-no-key-build")
set(_tip_fake_bin_dir "${_tip_case_root}/fake-bin")
set(_tip_fake_gpg_only_bin_dir "${_tip_case_root}/fake-gpg-only-bin")
set(_tip_tgz_package_dir "${_tip_case_root}/packages-tgz")
set(_tip_rpm_package_dir "${_tip_case_root}/packages-rpm")
set(_tip_both_no_rpm_package_dir "${_tip_case_root}/packages-both-no-rpm")
set(_tip_checksums_off_package_dir "${_tip_case_root}/packages-checksums-off")
set(_tip_checksums_only_package_dir "${_tip_case_root}/packages-checksums-only")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}")
file(MAKE_DIRECTORY "${_tip_no_rpm_source_dir}")
file(MAKE_DIRECTORY "${_tip_mixed_embedded_source_dir}")
file(MAKE_DIRECTORY "${_tip_both_no_rpm_source_dir}")
file(MAKE_DIRECTORY "${_tip_checksums_off_source_dir}")
file(MAKE_DIRECTORY "${_tip_checksums_only_source_dir}")
file(MAKE_DIRECTORY "${_tip_invalid_signing_method_source_dir}")
file(MAKE_DIRECTORY "${_tip_invalid_checksums_source_dir}")
file(MAKE_DIRECTORY "${_tip_explicit_sign_no_key_source_dir}")
file(MAKE_DIRECTORY "${_tip_fake_bin_dir}")
file(MAKE_DIRECTORY "${_tip_fake_gpg_only_bin_dir}")
file(MAKE_DIRECTORY "${_tip_tgz_package_dir}")
file(MAKE_DIRECTORY "${_tip_rpm_package_dir}")
file(MAKE_DIRECTORY "${_tip_both_no_rpm_package_dir}")
file(MAKE_DIRECTORY "${_tip_checksums_off_package_dir}")
file(MAKE_DIRECTORY "${_tip_checksums_only_package_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fake_bin_dir}/gpg"
  "#!/bin/sh\n"
  "case \"$1\" in\n"
  "  --list-secret-keys) exit 0 ;;\n"
  "esac\n"
  "out=''\n"
  "prev=''\n"
  "for arg in \"$@\"; do\n"
  "  if [ \"$prev\" = '--output' ]; then out=\"$arg\"; fi\n"
  "  prev=\"$arg\"\n"
  "done\n"
  "if [ -n \"$out\" ]; then printf 'signature\\n' > \"$out\"; fi\n"
  "printf '%s\\n' \"$@\" >> \"${_tip_case_root}/gpg.log\"\n"
  "exit 0\n")
file(COPY_FILE "${_tip_fake_bin_dir}/gpg" "${_tip_fake_bin_dir}/gpg2")
file(WRITE "${_tip_fake_bin_dir}/rpmsign" "#!/bin/sh\n" "printf '%s\\n' \"$@\" >> \"${_tip_case_root}/rpmsign.log\"\n" "exit 0\n")
file(COPY_FILE "${_tip_fake_bin_dir}/gpg" "${_tip_fake_gpg_only_bin_dir}/gpg")
file(COPY_FILE "${_tip_fake_bin_dir}/gpg" "${_tip_fake_gpg_only_bin_dir}/gpg2")
if(UNIX)
  file(
    CHMOD
    "${_tip_fake_bin_dir}/gpg"
    "${_tip_fake_bin_dir}/gpg2"
    "${_tip_fake_bin_dir}/rpmsign"
    "${_tip_fake_gpg_only_bin_dir}/gpg"
    "${_tip_fake_gpg_only_bin_dir}/gpg2"
    PERMISSIONS
    OWNER_READ
    OWNER_WRITE
    OWNER_EXECUTE
    GROUP_READ
    GROUP_EXECUTE
    WORLD_READ
    WORLD_EXECUTE)
endif()

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_signing_methods VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_signing_lib INTERFACE)\n"
  "target_install_package(proof_signing_lib)\n"
  "export_cpack(PACKAGE_NAME ProofSigning GENERATORS \"TGZ;RPM\" SIGNING_METHOD both GENERATE_CHECKSUMS ON)\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_bin_dir}:$ENV{PATH}" "GPG_SIGNING_KEY=proof@example.invalid" "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}"
                           "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_PROGRAM_PATH=${_tip_fake_bin_dir}" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "configure" COMMAND ${_tip_configure_command})

set(_tip_tgz_package "${_tip_tgz_package_dir}/proof.tar.gz")
file(WRITE "${_tip_tgz_package}" "tgz\n")

_tip_proof_run_step(
  NAME
  "run-signing-script-tgz-pass"
  COMMAND
  "${CMAKE_COMMAND}"
  "-DCPACK_PACKAGE_DIRECTORY=${_tip_tgz_package_dir}"
  -P
  "${_tip_build_dir}/sign_packages.cmake")

_tip_proof_assert_exists("${_tip_tgz_package_dir}/proof.tar.gz.sig")
_tip_proof_assert_exists("${_tip_tgz_package_dir}/proof.tar.gz.sha256")
_tip_proof_assert_exists("${_tip_tgz_package_dir}/proof.tar.gz.sha512")
_tip_proof_assert_file_contains("${_tip_case_root}/gpg.log" "--passphrase=")
_tip_proof_assert_not_exists("${_tip_case_root}/rpmsign.log")

set(_tip_rpm_package "${_tip_rpm_package_dir}/proof.rpm")
file(WRITE "${_tip_rpm_package}" "rpm\n")

_tip_proof_run_step(
  NAME
  "run-signing-script-rpm-pass"
  COMMAND
  "${CMAKE_COMMAND}"
  "-DCPACK_PACKAGE_DIRECTORY=${_tip_rpm_package_dir}"
  -P
  "${_tip_build_dir}/sign_packages.cmake")

_tip_proof_assert_exists("${_tip_rpm_package_dir}/proof.rpm.sig")
_tip_proof_assert_exists("${_tip_rpm_package_dir}/proof.rpm.sha256")
_tip_proof_assert_exists("${_tip_rpm_package_dir}/proof.rpm.sha512")
_tip_proof_assert_file_contains("${_tip_case_root}/rpmsign.log" "--addsign")
_tip_proof_assert_file_contains("${_tip_case_root}/rpmsign.log" "${_tip_rpm_package}")

file(
  WRITE "${_tip_both_no_rpm_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_signing_both_no_rpm VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_both_no_rpm_lib INTERFACE)\n"
  "target_install_package(proof_both_no_rpm_lib)\n"
  "export_cpack(PACKAGE_NAME ProofSigningBothNoRpm GENERATORS TGZ SIGNING_METHOD both GENERATE_CHECKSUMS ON)\n")

set(_tip_both_no_rpm_configure_command
    "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_gpg_only_bin_dir}:$ENV{PATH}" "GPG_SIGNING_KEY=proof@example.invalid" "${CMAKE_COMMAND}" -S "${_tip_both_no_rpm_source_dir}" -B
    "${_tip_both_no_rpm_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=FALSE" "-DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=FALSE"
    "-DCMAKE_PROGRAM_PATH=${_tip_fake_gpg_only_bin_dir}" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "both-no-rpm-configure-without-rpmsign" COMMAND ${_tip_both_no_rpm_configure_command})

set(_tip_both_no_rpm_package "${_tip_both_no_rpm_package_dir}/proof-both-no-rpm.tar.gz")
file(WRITE "${_tip_both_no_rpm_package}" "tgz\n")

_tip_proof_run_step(
  NAME
  "run-signing-script-both-no-rpm-pass"
  COMMAND
  "${CMAKE_COMMAND}"
  "-DCPACK_PACKAGE_DIRECTORY=${_tip_both_no_rpm_package_dir}"
  -P
  "${_tip_both_no_rpm_build_dir}/sign_packages.cmake")

_tip_proof_assert_exists("${_tip_both_no_rpm_package_dir}/proof-both-no-rpm.tar.gz.sig")
_tip_proof_assert_exists("${_tip_both_no_rpm_package_dir}/proof-both-no-rpm.tar.gz.sha256")
_tip_proof_assert_exists("${_tip_both_no_rpm_package_dir}/proof-both-no-rpm.tar.gz.sha512")

file(
  WRITE "${_tip_checksums_off_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_signing_checksums_off VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_checksums_off_lib INTERFACE)\n"
  "target_install_package(proof_checksums_off_lib)\n"
  "export_cpack(PACKAGE_NAME ProofSigningChecksumsOff GENERATORS TGZ SIGNING_METHOD detached GENERATE_CHECKSUMS OFF)\n")

set(_tip_checksums_off_configure_command
    "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_gpg_only_bin_dir}:$ENV{PATH}" "GPG_SIGNING_KEY=proof@example.invalid" "${CMAKE_COMMAND}" -S "${_tip_checksums_off_source_dir}" -B
    "${_tip_checksums_off_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=FALSE" "-DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=FALSE"
    "-DCMAKE_PROGRAM_PATH=${_tip_fake_gpg_only_bin_dir}" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "checksums-off-configure" COMMAND ${_tip_checksums_off_configure_command})

set(_tip_checksums_off_package "${_tip_checksums_off_package_dir}/proof-checksums-off.tar.gz")
file(WRITE "${_tip_checksums_off_package}" "tgz\n")

_tip_proof_run_step(
  NAME
  "run-signing-script-checksums-off-pass"
  COMMAND
  "${CMAKE_COMMAND}"
  "-DCPACK_PACKAGE_DIRECTORY=${_tip_checksums_off_package_dir}"
  -P
  "${_tip_checksums_off_build_dir}/sign_packages.cmake")

_tip_proof_assert_exists("${_tip_checksums_off_package_dir}/proof-checksums-off.tar.gz.sig")
_tip_proof_assert_not_exists("${_tip_checksums_off_package_dir}/proof-checksums-off.tar.gz.sha256")
_tip_proof_assert_not_exists("${_tip_checksums_off_package_dir}/proof-checksums-off.tar.gz.sha512")

file(
  WRITE "${_tip_checksums_only_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_checksums_only VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_checksums_only_lib INTERFACE)\n"
  "target_install_package(proof_checksums_only_lib)\n"
  "export_cpack(PACKAGE_NAME ProofChecksumsOnly GENERATORS TGZ GENERATE_CHECKSUMS ON)\n")

set(_tip_checksums_only_configure_command
    "${CMAKE_COMMAND}" -E env "GPG_SIGNING_KEY=" "${CMAKE_COMMAND}" -S "${_tip_checksums_only_source_dir}" -B "${_tip_checksums_only_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args})

_tip_proof_run_step(NAME "checksums-only-configure-without-signing-key" COMMAND ${_tip_checksums_only_configure_command})
_tip_proof_assert_file_contains("${_tip_checksums_only_build_dir}/sign_packages.cmake" "set(SIGNING_METHOD \"none\")")
_tip_proof_assert_file_contains("${_tip_checksums_only_build_dir}/sign_packages.cmake" "set(GPG_EXECUTABLE \"\")")

set(_tip_checksums_only_package "${_tip_checksums_only_package_dir}/proof-checksums-only.tar.gz")
file(WRITE "${_tip_checksums_only_package}" "tgz\n")
file(WRITE "${_tip_checksums_only_package}.sig" "stale signature\n")

_tip_proof_run_step(
  NAME
  "run-checksums-only-script-pass"
  COMMAND
  "${CMAKE_COMMAND}"
  "-DCPACK_PACKAGE_DIRECTORY=${_tip_checksums_only_package_dir}"
  -P
  "${_tip_checksums_only_build_dir}/sign_packages.cmake")

_tip_proof_assert_not_exists("${_tip_checksums_only_package_dir}/proof-checksums-only.tar.gz.sig")
_tip_proof_assert_exists("${_tip_checksums_only_package_dir}/proof-checksums-only.tar.gz.sha256")
_tip_proof_assert_exists("${_tip_checksums_only_package_dir}/proof-checksums-only.tar.gz.sha512")

file(
  WRITE "${_tip_explicit_sign_no_key_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_explicit_sign_no_key VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_explicit_sign_no_key_lib INTERFACE)\n"
  "target_install_package(proof_explicit_sign_no_key_lib)\n"
  "export_cpack(PACKAGE_NAME ProofExplicitSignNoKey GENERATORS TGZ SIGNING_METHOD detached GENERATE_CHECKSUMS ON)\n")

set(_tip_explicit_sign_no_key_configure_command
    "${CMAKE_COMMAND}" -E env "GPG_SIGNING_KEY=" "${CMAKE_COMMAND}" -S "${_tip_explicit_sign_no_key_source_dir}" -B "${_tip_explicit_sign_no_key_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "explicit-signing-method-requires-key"
  COMMAND
  ${_tip_explicit_sign_no_key_configure_command}
  EXPECT_CONTAINS
  "SIGNING_METHOD 'detached'"
  "requires GPG_SIGNING_KEY")

file(
  WRITE "${_tip_invalid_signing_method_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_invalid_signing_method VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_invalid_signing_method_lib INTERFACE)\n"
  "target_install_package(proof_invalid_signing_method_lib)\n"
  "export_cpack(PACKAGE_NAME ProofInvalidSigningMethod GENERATORS TGZ SIGNING_METHOD bananas)\n")

set(_tip_invalid_signing_method_configure_command
    "${CMAKE_COMMAND}" -E env "GPG_SIGNING_KEY=" "${CMAKE_COMMAND}" -S "${_tip_invalid_signing_method_source_dir}" -B "${_tip_invalid_signing_method_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "invalid-signing-method-without-signing-key"
  COMMAND
  ${_tip_invalid_signing_method_configure_command}
  EXPECT_CONTAINS
  "SIGNING_METHOD"
  "bananas")

file(
  WRITE "${_tip_invalid_checksums_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_invalid_checksums VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_invalid_checksums_lib INTERFACE)\n"
  "target_install_package(proof_invalid_checksums_lib)\n"
  "export_cpack(PACKAGE_NAME ProofInvalidChecksums GENERATORS TGZ GENERATE_CHECKSUMS maybe)\n")

set(_tip_invalid_checksums_configure_command
    "${CMAKE_COMMAND}" -E env "GPG_SIGNING_KEY=" "${CMAKE_COMMAND}" -S "${_tip_invalid_checksums_source_dir}" -B "${_tip_invalid_checksums_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "invalid-generate-checksums-value"
  COMMAND
  ${_tip_invalid_checksums_configure_command}
  EXPECT_CONTAINS
  "GENERATE_CHECKSUMS"
  "maybe")

file(
  WRITE "${_tip_no_rpm_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_signing_no_rpm VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_no_rpm_lib INTERFACE)\n"
  "target_install_package(proof_no_rpm_lib)\n"
  "export_cpack(PACKAGE_NAME ProofSigningNoRpm GENERATORS TGZ SIGNING_METHOD embedded)\n")

set(_tip_no_rpm_configure_command "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_bin_dir}:$ENV{PATH}" "GPG_SIGNING_KEY=proof@example.invalid" "${CMAKE_COMMAND}" -S "${_tip_no_rpm_source_dir}" -B
                                  "${_tip_no_rpm_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_PROGRAM_PATH=${_tip_fake_bin_dir}" ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "embedded-signing-without-rpm-generator"
  COMMAND
  ${_tip_no_rpm_configure_command}
  EXPECT_CONTAINS
  "SIGNING_METHOD 'embedded'"
  "supports RPM")

file(
  WRITE "${_tip_mixed_embedded_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_gpg_signing_mixed_embedded VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_mixed_embedded_lib INTERFACE)\n"
  "target_install_package(proof_mixed_embedded_lib)\n"
  "export_cpack(PACKAGE_NAME ProofSigningMixedEmbedded GENERATORS \"TGZ;RPM\" SIGNING_METHOD embedded)\n")

set(_tip_mixed_embedded_configure_command
    "${CMAKE_COMMAND}" -E env "PATH=${_tip_fake_bin_dir}:$ENV{PATH}" "GPG_SIGNING_KEY=proof@example.invalid" "${CMAKE_COMMAND}" -S "${_tip_mixed_embedded_source_dir}" -B
    "${_tip_mixed_embedded_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_PROGRAM_PATH=${_tip_fake_bin_dir}" ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "embedded-signing-with-mixed-generators"
  COMMAND
  ${_tip_mixed_embedded_configure_command}
  EXPECT_CONTAINS
  "SIGNING_METHOD 'embedded'"
  "supports RPM")

message(STATUS "[proof] GPG signing methods proof passed.")
