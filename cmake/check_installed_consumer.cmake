# See docs/installed-consumer-check.md for inputs and a consumer example.
CMAKE_MINIMUM_REQUIRED(VERSION 3.25)

IF(TIP_CHECK_SETTINGS)
  INCLUDE("${TIP_CHECK_SETTINGS}")
ENDIF()

FOREACH(_tip_required IN ITEMS PRODUCER CONSUMER PACKAGE WORK_ROOT)
  IF(NOT DEFINED TIP_CHECK_${_tip_required} OR "${TIP_CHECK_${_tip_required}}" STREQUAL "")
    MESSAGE(FATAL_ERROR "[consumer-check] TIP_CHECK_${_tip_required} is required")
  ENDIF()
ENDFOREACH()

FOREACH(_tip_source IN ITEMS PRODUCER CONSUMER)
  GET_FILENAME_COMPONENT(TIP_CHECK_${_tip_source} "${TIP_CHECK_${_tip_source}}" ABSOLUTE)
  IF(NOT EXISTS "${TIP_CHECK_${_tip_source}}/CMakeLists.txt")
    MESSAGE(FATAL_ERROR "[consumer-check] TIP_CHECK_${_tip_source} must contain CMakeLists.txt")
  ENDIF()
ENDFOREACH()

IF(NOT DEFINED TIP_CHECK_CONFIG)
  SET(TIP_CHECK_CONFIG Release)
ENDIF()
IF(TIP_CHECK_CONFIG STREQUAL "")
  MESSAGE(FATAL_ERROR "[consumer-check] TIP_CHECK_CONFIG must name a build configuration")
ENDIF()
IF(NOT DEFINED TIP_CHECK_RUN_TESTS)
  SET(TIP_CHECK_RUN_TESTS AUTO)
ENDIF()
IF(NOT TIP_CHECK_RUN_TESTS MATCHES "^(AUTO|ON|OFF)$")
  MESSAGE(FATAL_ERROR "[consumer-check] TIP_CHECK_RUN_TESTS must be AUTO, ON, or OFF")
ENDIF()

# Create only a new owned child directory; retain all evidence on success or failure.
GET_FILENAME_COMPONENT(TIP_CHECK_WORK_ROOT "${TIP_CHECK_WORK_ROOT}" ABSOLUTE)
STRING(
  RANDOM
  LENGTH 16
  ALPHABET 0123456789abcdef _tip_run_id)
SET(_tip_run "${TIP_CHECK_WORK_ROOT}/consumer-check-${_tip_run_id}")
IF(EXISTS "${_tip_run}")
  MESSAGE(FATAL_ERROR "[consumer-check] Refusing to reuse existing run directory: ${_tip_run}")
ENDIF()
FILE(MAKE_DIRECTORY "${_tip_run}")
MESSAGE(STATUS "[consumer-check] Evidence: ${_tip_run}")

FUNCTION(_tip_check_run stage)
  CMAKE_PARSE_ARGUMENTS(PARSE_ARGV 1 arg "" "" "COMMAND")
  MESSAGE(STATUS "[consumer-check] ${stage}")
  EXECUTE_PROCESS(
    COMMAND ${arg_COMMAND}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_out
    ERROR_VARIABLE _tip_err)
  FILE(WRITE "${_tip_run}/${stage}.log" "${_tip_out}\n${_tip_err}")
  IF(NOT "${_tip_result}" STREQUAL "0")
    MESSAGE(FATAL_ERROR "[consumer-check] ${stage} failed (${_tip_result}).\nLog: ${_tip_run}/${stage}.log\n${_tip_out}\n${_tip_err}")
  ENDIF()
ENDFUNCTION()

# Cache values may contain CMake bracket delimiters, including in valid host paths.
FUNCTION(_tip_check_cache_value path name type value)
  SET(_tip_equals "=")
  WHILE("${value}" MATCHES "\\]${_tip_equals}\\]")
    STRING(APPEND _tip_equals "=")
  ENDWHILE()
  FILE(APPEND "${path}" "set(${name} [${_tip_equals}[${value}]${_tip_equals}] CACHE ${type} \"\" FORCE)\n")
ENDFUNCTION()

# Keep the generator, toolchain, and configuration consistent across all three builds.
SET(_tip_common_args "-DCMAKE_BUILD_TYPE=${TIP_CHECK_CONFIG}")
IF(TIP_CHECK_GENERATOR)
  LIST(APPEND _tip_common_args -G "${TIP_CHECK_GENERATOR}")
ENDIF()
IF(TIP_CHECK_TOOLCHAIN_FILE)
  GET_FILENAME_COMPONENT(TIP_CHECK_TOOLCHAIN_FILE "${TIP_CHECK_TOOLCHAIN_FILE}" ABSOLUTE)
  LIST(APPEND _tip_common_args "-DCMAKE_TOOLCHAIN_FILE=${TIP_CHECK_TOOLCHAIN_FILE}")
ENDIF()

SET(_tip_prefix "${_tip_run}/install")
_TIP_CHECK_RUN(
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
_TIP_CHECK_RUN(
  producer-build
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_run}/producer"
  --config
  "${TIP_CHECK_CONFIG}")
_TIP_CHECK_RUN(
  producer-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_run}/producer"
  --config
  "${TIP_CHECK_CONFIG}"
  --prefix
  "${_tip_prefix}")
IF(NOT IS_DIRECTORY "${_tip_prefix}")
  MESSAGE(FATAL_ERROR "[consumer-check] Producer installed no prefix: ${_tip_prefix}")
ENDIF()

FUNCTION(_tip_check_consumer phase prefix)
  SET(_tip_build "${_tip_run}/${phase}-consumer")

  # An initial cache preserves list-valued dependency paths and emulator arguments.
  SET(_tip_cache "${_tip_run}/${phase}-cache.cmake")
  FILE(WRITE "${_tip_cache}" "")
  _tip_check_cache_value("${_tip_cache}" CMAKE_PREFIX_PATH STRING "${prefix};${TIP_CHECK_PREFIX_PATH}")

  # Staged host paths bypass sysroot rerooting without changing dependency search policy.
  _tip_check_cache_value("${_tip_cache}" CMAKE_STAGING_PREFIX PATH "${prefix}")
  IF(TIP_CHECK_EMULATOR)
    _tip_check_cache_value("${_tip_cache}" CMAKE_CROSSCOMPILING_EMULATOR STRING "${TIP_CHECK_EMULATOR}")
  ENDIF()
  _TIP_CHECK_RUN(
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
  LOAD_CACHE("${_tip_build}" READ_WITH_PREFIX _tip_found_ "${TIP_CHECK_PACKAGE}_DIR")
  SET(_tip_package_dir "${_tip_found_${TIP_CHECK_PACKAGE}_DIR}")
  IF(NOT IS_DIRECTORY "${_tip_package_dir}")
    MESSAGE(FATAL_ERROR "[consumer-check] Consumer must call find_package(${TIP_CHECK_PACKAGE} CONFIG REQUIRED); no cached package directory was found")
  ENDIF()
  FILE(REAL_PATH "${prefix}" _tip_real_prefix)
  FILE(REAL_PATH "${_tip_package_dir}" _tip_real_package_dir)
  CMAKE_PATH(IS_PREFIX _tip_real_prefix "${_tip_real_package_dir}" NORMALIZE _tip_from_install)
  IF(NOT _tip_from_install)
    MESSAGE(FATAL_ERROR "[consumer-check] ${TIP_CHECK_PACKAGE} resolved outside the tested prefix: ${_tip_package_dir}")
  ENDIF()

  _TIP_CHECK_RUN(
    ${phase}-build
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_build}"
    --config
    "${TIP_CHECK_CONFIG}")

  # Use CMake's configured target platform, rather than guessing from the host OS.
  FILE(GLOB _tip_system_files "${_tip_build}/CMakeFiles/*/CMakeSystem.cmake")
  LIST(LENGTH _tip_system_files _tip_system_count)
  IF(NOT _tip_system_count EQUAL 1)
    MESSAGE(FATAL_ERROR "[consumer-check] Cannot determine consumer cross-compilation state in ${_tip_build}")
  ENDIF()
  INCLUDE("${_tip_system_files}")
  IF(TIP_CHECK_RUN_TESTS STREQUAL "OFF"
     OR (TIP_CHECK_RUN_TESTS STREQUAL "AUTO"
         AND CMAKE_CROSSCOMPILING
         AND NOT TIP_CHECK_EMULATOR))
    MESSAGE(STATUS "[consumer-check] ${phase}: runtime checks skipped (mode=${TIP_CHECK_RUN_TESTS}, cross-compiling=${CMAKE_CROSSCOMPILING})")
  ELSE()
    _TIP_CHECK_RUN(
      ${phase}-test
      COMMAND
      "${CMAKE_CTEST_COMMAND}"
      --test-dir
      "${_tip_build}"
      --build-config
      "${TIP_CHECK_CONFIG}"
      --output-on-failure
      --no-tests=error)
  ENDIF()
ENDFUNCTION()

_TIP_CHECK_CONSUMER(installed "${_tip_prefix}")

# Rename, rather than copy: references to the original installation must break.
SET(_tip_relocated "${_tip_run}/relocated")
FILE(RENAME "${_tip_prefix}" "${_tip_relocated}")
_TIP_CHECK_CONSUMER(relocated "${_tip_relocated}")
MESSAGE(STATUS "[consumer-check] Installed and relocated consumer checks passed. Evidence: ${_tip_run}")
