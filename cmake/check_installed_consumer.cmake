# See docs/installed-consumer-check.md for inputs and a consumer example.
cmake_minimum_required(VERSION 3.25)

if(TIP_CHECK_SETTINGS)
  include("${TIP_CHECK_SETTINGS}")
endif()

foreach(_tip_required IN ITEMS PRODUCER CONSUMER PACKAGE WORK_ROOT)
  if(NOT DEFINED TIP_CHECK_${_tip_required} OR "${TIP_CHECK_${_tip_required}}" STREQUAL "")
    message(FATAL_ERROR "[consumer-check] TIP_CHECK_${_tip_required} is required")
  endif()
endforeach()

foreach(_tip_source IN ITEMS PRODUCER CONSUMER)
  get_filename_component(TIP_CHECK_${_tip_source} "${TIP_CHECK_${_tip_source}}" ABSOLUTE)
  if(NOT EXISTS "${TIP_CHECK_${_tip_source}}/CMakeLists.txt")
    message(FATAL_ERROR "[consumer-check] TIP_CHECK_${_tip_source} must contain CMakeLists.txt")
  endif()
endforeach()

if(NOT DEFINED TIP_CHECK_CONFIG)
  set(TIP_CHECK_CONFIG Release)
endif()
if(TIP_CHECK_CONFIG STREQUAL "")
  message(FATAL_ERROR "[consumer-check] TIP_CHECK_CONFIG must name a build configuration")
endif()
if(NOT DEFINED TIP_CHECK_RUN_TESTS)
  set(TIP_CHECK_RUN_TESTS AUTO)
endif()
if(NOT TIP_CHECK_RUN_TESTS MATCHES "^(AUTO|ON|OFF)$")
  message(FATAL_ERROR "[consumer-check] TIP_CHECK_RUN_TESTS must be AUTO, ON, or OFF")
endif()

# Create only a new owned child directory; retain all evidence on success or failure.
get_filename_component(TIP_CHECK_WORK_ROOT "${TIP_CHECK_WORK_ROOT}" ABSOLUTE)
string(
  RANDOM
  LENGTH 16
  ALPHABET 0123456789abcdef _tip_run_id)
set(_tip_run "${TIP_CHECK_WORK_ROOT}/consumer-check-${_tip_run_id}")
if(EXISTS "${_tip_run}")
  message(FATAL_ERROR "[consumer-check] Refusing to reuse existing run directory: ${_tip_run}")
endif()
file(MAKE_DIRECTORY "${_tip_run}")
message(STATUS "[consumer-check] Evidence: ${_tip_run}")

function(_tip_check_run stage)
  cmake_parse_arguments(PARSE_ARGV 1 arg "" "" "COMMAND")
  message(STATUS "[consumer-check] ${stage}")
  execute_process(
    COMMAND ${arg_COMMAND}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_out
    ERROR_VARIABLE _tip_err)
  file(WRITE "${_tip_run}/${stage}.log" "${_tip_out}\n${_tip_err}")
  if(NOT "${_tip_result}" STREQUAL "0")
    message(FATAL_ERROR "[consumer-check] ${stage} failed (${_tip_result}).\nLog: ${_tip_run}/${stage}.log\n${_tip_out}\n${_tip_err}")
  endif()
endfunction()

# Cache values may contain CMake bracket delimiters, including in valid host paths.
function(_tip_check_cache_value path name type value)
  set(_tip_equals "=")
  while("${value}" MATCHES "\\]${_tip_equals}\\]")
    string(APPEND _tip_equals "=")
  endwhile()
  file(APPEND "${path}" "set(${name} [${_tip_equals}[${value}]${_tip_equals}] CACHE ${type} \"\" FORCE)\n")
endfunction()

# Keep the generator, toolchain, and configuration consistent across all three builds.
set(_tip_common_args "-DCMAKE_BUILD_TYPE=${TIP_CHECK_CONFIG}")
if(TIP_CHECK_GENERATOR)
  list(APPEND _tip_common_args -G "${TIP_CHECK_GENERATOR}")
endif()
if(TIP_CHECK_TOOLCHAIN_FILE)
  get_filename_component(TIP_CHECK_TOOLCHAIN_FILE "${TIP_CHECK_TOOLCHAIN_FILE}" ABSOLUTE)
  list(APPEND _tip_common_args "-DCMAKE_TOOLCHAIN_FILE=${TIP_CHECK_TOOLCHAIN_FILE}")
endif()

set(_tip_prefix "${_tip_run}/install")
_tip_check_run(
  producer-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${TIP_CHECK_PRODUCER}"
  -B
  "${_tip_run}/producer"
  ${TIP_CHECK_PRODUCER_ARGS}
  ${_tip_common_args}
  "-DCMAKE_INSTALL_PREFIX=${_tip_prefix}")
_tip_check_run(
  producer-build
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_run}/producer"
  --config
  "${TIP_CHECK_CONFIG}")
_tip_check_run(
  producer-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_run}/producer"
  --config
  "${TIP_CHECK_CONFIG}"
  --prefix
  "${_tip_prefix}")
if(NOT IS_DIRECTORY "${_tip_prefix}")
  message(FATAL_ERROR "[consumer-check] Producer installed no prefix: ${_tip_prefix}")
endif()

function(_tip_check_consumer phase prefix)
  set(_tip_build "${_tip_run}/${phase}-consumer")

  # An initial cache preserves list-valued dependency paths and emulator arguments.
  set(_tip_cache "${_tip_run}/${phase}-cache.cmake")
  file(WRITE "${_tip_cache}" "")
  _tip_check_cache_value("${_tip_cache}" CMAKE_PREFIX_PATH STRING "${prefix};${TIP_CHECK_PREFIX_PATH}")

  # Staged host paths bypass sysroot rerooting without changing dependency search policy.
  _tip_check_cache_value("${_tip_cache}" CMAKE_STAGING_PREFIX PATH "${prefix}")
  if(TIP_CHECK_EMULATOR)
    _tip_check_cache_value("${_tip_cache}" CMAKE_CROSSCOMPILING_EMULATOR STRING "${TIP_CHECK_EMULATOR}")
  endif()
  _tip_check_run(
    ${phase}-configure
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${TIP_CHECK_CONSUMER}"
    -B
    "${_tip_build}"
    -C
    "${_tip_cache}"
    ${TIP_CHECK_CONSUMER_ARGS}
    ${_tip_common_args}
    "-DTIP_CHECK_PREFIX=${prefix}"
    -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF
    -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF)

  # A system or user installation must never stand in for the package being tested.
  load_cache("${_tip_build}" READ_WITH_PREFIX _tip_found_ "${TIP_CHECK_PACKAGE}_DIR")
  set(_tip_package_dir "${_tip_found_${TIP_CHECK_PACKAGE}_DIR}")
  if(NOT IS_DIRECTORY "${_tip_package_dir}")
    message(FATAL_ERROR "[consumer-check] Consumer must call find_package(${TIP_CHECK_PACKAGE} CONFIG REQUIRED); no cached package directory was found")
  endif()
  file(REAL_PATH "${prefix}" _tip_real_prefix)
  file(REAL_PATH "${_tip_package_dir}" _tip_real_package_dir)
  cmake_path(IS_PREFIX _tip_real_prefix "${_tip_real_package_dir}" NORMALIZE _tip_from_install)
  if(NOT _tip_from_install)
    message(FATAL_ERROR "[consumer-check] ${TIP_CHECK_PACKAGE} resolved outside the tested prefix: ${_tip_package_dir}")
  endif()

  _tip_check_run(
    ${phase}-build
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_build}"
    --config
    "${TIP_CHECK_CONFIG}")

  # Use CMake's configured target platform, rather than guessing from the host OS.
  file(GLOB _tip_system_files "${_tip_build}/CMakeFiles/*/CMakeSystem.cmake")
  list(LENGTH _tip_system_files _tip_system_count)
  if(NOT _tip_system_count EQUAL 1)
    message(FATAL_ERROR "[consumer-check] Cannot determine consumer cross-compilation state in ${_tip_build}")
  endif()
  include("${_tip_system_files}")
  if(TIP_CHECK_RUN_TESTS STREQUAL "OFF"
     OR (TIP_CHECK_RUN_TESTS STREQUAL "AUTO"
         AND CMAKE_CROSSCOMPILING
         AND NOT TIP_CHECK_EMULATOR))
    message(STATUS "[consumer-check] ${phase}: runtime checks skipped (mode=${TIP_CHECK_RUN_TESTS}, cross-compiling=${CMAKE_CROSSCOMPILING})")
  else()
    _tip_check_run(
      ${phase}-test
      COMMAND
      "${CMAKE_CTEST_COMMAND}"
      --test-dir
      "${_tip_build}"
      --build-config
      "${TIP_CHECK_CONFIG}"
      --output-on-failure
      --no-tests=error)
  endif()
endfunction()

_tip_check_consumer(installed "${_tip_prefix}")

# Rename, rather than copy: references to the original installation must break.
set(_tip_relocated "${_tip_run}/relocated")
file(RENAME "${_tip_prefix}" "${_tip_relocated}")
_tip_check_consumer(relocated "${_tip_relocated}")
message(STATUS "[consumer-check] Installed and relocated consumer checks passed. Evidence: ${_tip_run}")
