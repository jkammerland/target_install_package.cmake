cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT TIP_REPO_ROOT OR NOT TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT and TIP_PROOF_TEST_ROOT are required")
endif()

set(_root "${TIP_PROOF_TEST_ROOT}/basic-static-consumption")
set(_producer "${TIP_REPO_ROOT}/examples/basic-static")
file(REMOVE_RECURSE "${_root}")
_tip_proof_append_toolchain_args(_toolchain_args)

# The standalone default must produce a usable installed package.
_tip_proof_run_step(
  NAME
  producer-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_producer}"
  -B
  "${_root}/producer"
  -DCMAKE_BUILD_TYPE=Release
  ${_toolchain_args})
_tip_proof_run_step(
  NAME
  producer-build
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_root}/producer"
  --config
  Release)
_tip_proof_run_step(
  NAME
  producer-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_root}/producer"
  --config
  Release
  --prefix
  "${_root}/prefix")
_tip_proof_assert_exists("${_root}/prefix/share/cmake/math_lib/math_libConfig.cmake")

# One actual API consumer must link with either source or installed dependency resolution.
foreach(_mode IN ITEMS source installed)
  set(_args "-DCMAKE_PREFIX_PATH=${_root}/prefix")
  if(_mode STREQUAL "source")
    set(_args -DMATH_FROM_SOURCE=ON)
  endif()

  _tip_proof_run_step(
    NAME
    "${_mode}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_producer}/consumer"
    -B
    "${_root}/${_mode}"
    -DCMAKE_BUILD_TYPE=Release
    ${_args}
    ${_toolchain_args})
  _tip_proof_run_step(
    NAME
    "${_mode}-build"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_root}/${_mode}"
    --config
    Release)
  if(NOT TIP_CMAKE_TOOLCHAIN_FILE)
    _tip_proof_run_step(
      NAME
      "${_mode}-run"
      COMMAND
      "${CMAKE_CTEST_COMMAND}"
      --test-dir
      "${_root}/${_mode}"
      -C
      Release
      --output-on-failure
      --no-tests=error)
  endif()
endforeach()

# Embedded consumption must leave both the option and the installed payload empty.
_tip_proof_assert_file_contains("${_root}/source/CMakeCache.txt" "MATH_INSTALL:BOOL=OFF")
_tip_proof_run_step(
  NAME
  source-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_root}/source"
  --config
  Release
  --prefix
  "${_root}/embedded-prefix")
file(READ "${_root}/source/install_manifest.txt" _manifest)
if(NOT _manifest STREQUAL "")
  _tip_proof_fail("Embedded default installed unexpected files: ${_manifest}")
endif()
