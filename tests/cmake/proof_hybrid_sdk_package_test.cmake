cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

function(_tip_hybrid_sdk_executable_path build_dir configuration out_var)
  file(STRINGS "${build_dir}/CMakeCache.txt" _tip_configuration_types REGEX "^CMAKE_CONFIGURATION_TYPES:[^=]*=")
  set(_tip_executable_path "${build_dir}/hybrid_sdk_consumer${CMAKE_EXECUTABLE_SUFFIX}")
  if(_tip_configuration_types)
    set(_tip_executable_path "${build_dir}/${configuration}/hybrid_sdk_consumer${CMAKE_EXECUTABLE_SUFFIX}")
  endif()
  set(${out_var}
      "${_tip_executable_path}"
      PARENT_SCOPE)
endfunction()

function(_tip_hybrid_sdk_run_case name source_destination expected_source_destination)
  set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/hybrid-sdk/${name}")
  set(_tip_producer_root "${_tip_case_root}/producer")
  set(_tip_producer_source_dir "${_tip_producer_root}/hybrid-sdk")
  set(_tip_producer_build_dir "${_tip_case_root}/producer-build")
  set(_tip_install_prefix "${_tip_case_root}/install")
  set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
  set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")
  set(_tip_build_config "Release")

  file(REMOVE_RECURSE "${_tip_case_root}")
  file(MAKE_DIRECTORY "${_tip_producer_root}")
  file(COPY "${TIP_REPO_ROOT}/examples/hybrid-sdk" DESTINATION "${_tip_producer_root}")

  _tip_proof_append_toolchain_args(_tip_toolchain_args)
  set(_tip_producer_configure_command
      "${CMAKE_COMMAND}"
      -S
      "${_tip_producer_source_dir}"
      -B
      "${_tip_producer_build_dir}"
      "-DCMAKE_BUILD_TYPE=${_tip_build_config}"
      "-DTARGET_INSTALL_PACKAGE_ROOT=${TIP_REPO_ROOT}")
  if(NOT "${source_destination}" STREQUAL "")
    list(APPEND _tip_producer_configure_command "-DHYBRID_SDK_SOURCE_DESTINATION=${source_destination}")
  endif()
  list(APPEND _tip_producer_configure_command ${_tip_toolchain_args})
  _tip_proof_run_step(NAME "${name}-producer-configure" COMMAND ${_tip_producer_configure_command})
  _tip_proof_run_step(NAME "${name}-producer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_producer_build_dir}" --config "${_tip_build_config}")
  _tip_proof_run_step(
    NAME
    "${name}-producer-install"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_tip_producer_build_dir}"
    --config
    "${_tip_build_config}"
    --prefix
    "${_tip_install_prefix}")

  _tip_proof_assert_exists("${_tip_install_prefix}/${expected_source_destination}/extension.cpp")
  _tip_proof_assert_exists("${_tip_install_prefix}/include/hybrid/sdk.hpp")

  file(REMOVE_RECURSE "${_tip_producer_source_dir}" "${_tip_producer_build_dir}")
  file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
  file(
    WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 4.4)\n"
    "project(hybrid_sdk_consumer LANGUAGES CXX)\n"
    "find_package(hybrid_sdk 1.0 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
    "get_property(_tip_runtime_configurations_set TARGET HybridSdk::runtime PROPERTY IMPORTED_CONFIGURATIONS SET)\n"
    "set(_tip_runtime_locations)\n"
    "if(_tip_runtime_configurations_set)\n"
    "  get_target_property(_tip_runtime_configurations HybridSdk::runtime IMPORTED_CONFIGURATIONS)\n"
    "  foreach(_tip_runtime_configuration IN LISTS _tip_runtime_configurations)\n"
    "    string(TOUPPER \"\${_tip_runtime_configuration}\" _tip_runtime_configuration_upper)\n"
    "    get_target_property(_tip_runtime_location HybridSdk::runtime \"IMPORTED_LOCATION_\${_tip_runtime_configuration_upper}\")\n"
    "    list(APPEND _tip_runtime_locations \"\${_tip_runtime_location}\")\n"
    "  endforeach()\n"
    "else()\n"
    "  get_target_property(_tip_runtime_location HybridSdk::runtime IMPORTED_LOCATION_NOCONFIG)\n"
    "  list(APPEND _tip_runtime_locations \"\${_tip_runtime_location}\")\n"
    "endif()\n"
    "foreach(_tip_runtime_location IN LISTS _tip_runtime_locations)\n"
    "  if(NOT EXISTS \"\${_tip_runtime_location}\")\n"
    "    message(FATAL_ERROR \"Hybrid runtime did not resolve to an installed binary: \${_tip_runtime_location}\")\n"
    "  endif()\n"
    "  string(FIND \"\${_tip_runtime_location}\" \"${_tip_install_prefix}/\" _tip_runtime_prefix_index)\n"
    "  if(NOT _tip_runtime_prefix_index EQUAL 0)\n"
    "    message(FATAL_ERROR \"Hybrid runtime escaped the relocated prefix: \${_tip_runtime_location}\")\n"
    "  endif()\n"
    "endforeach()\n"
    "get_target_property(_tip_source_sets HybridSdk::extension INTERFACE_SOURCE_SETS)\n"
    "if(NOT implementation IN_LIST _tip_source_sets)\n"
    "  message(FATAL_ERROR \"Hybrid extension lost its installed source set: \${_tip_source_sets}\")\n"
    "endif()\n"
    "get_target_property(_tip_source_files HybridSdk::extension SOURCE_SET_implementation)\n"
    "foreach(_tip_source_file IN LISTS _tip_source_files)\n"
    "  string(FIND \"\${_tip_source_file}\" \"${_tip_install_prefix}/\" _tip_source_prefix_index)\n"
    "  if(NOT _tip_source_prefix_index EQUAL 0)\n"
    "    message(FATAL_ERROR \"Hybrid extension source escaped the relocated prefix: \${_tip_source_file}\")\n"
    "  endif()\n"
    "endforeach()\n"
    "add_executable(hybrid_sdk_consumer main.cpp)\n"
    "target_link_libraries(hybrid_sdk_consumer PRIVATE HybridSdk::sdk)\n"
    "if(WIN32)\n"
    "  add_custom_command(TARGET hybrid_sdk_consumer POST_BUILD COMMAND \"\${CMAKE_COMMAND}\" -E copy -t \"\$<TARGET_FILE_DIR:hybrid_sdk_consumer>\" \"\$<TARGET_RUNTIME_DLLS:hybrid_sdk_consumer>\" COMMAND_EXPAND_LISTS)\n"
    "endif()\n")
  file(WRITE "${_tip_consumer_source_dir}/main.cpp" "#include <hybrid/sdk.hpp>\nint main() { return hybrid_extension_value() == 42 ? 0 : 1; }\n")

  _tip_proof_run_step(
    NAME
    "${name}-consumer-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_consumer_source_dir}"
    -B
    "${_tip_consumer_build_dir}"
    "-DCMAKE_BUILD_TYPE=${_tip_build_config}"
    ${_tip_toolchain_args})
  _tip_proof_run_step(NAME "${name}-consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}" --config "${_tip_build_config}")
  _tip_hybrid_sdk_executable_path("${_tip_consumer_build_dir}" "${_tip_build_config}" _tip_consumer_executable)
  _tip_proof_run_step(NAME "${name}-consumer-run" COMMAND "${_tip_consumer_executable}")
endfunction()

_tip_hybrid_sdk_run_case("default-destination" "" "share/hybrid_sdk/src")
_tip_hybrid_sdk_run_case("custom-destination" "share/hybrid-sdk/custom-sources" "share/hybrid-sdk/custom-sources")

message(STATUS "[proof] Hybrid SDK package proof passed.")
