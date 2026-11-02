cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/registration-context")
set(_tip_source "${_tip_case_root}/source with spaces")
set(_tip_build "${_tip_case_root}/build")
set(_tip_install "${_tip_case_root}/install")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source}/a" "${_tip_source}/b")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

set(_tip_root
    [=[
cmake_minimum_required(VERSION 3.25)
project(Root VERSION 9.8.7 LANGUAGES CXX)
include("@TIP_REPO_ROOT@/target_install_package.cmake")
set(CHILD_TOKEN root)
set(PACKAGE_VENDOR root_vendor)
add_subdirectory(a)
add_subdirectory(b)
set(CHILD_TOKEN root_after)
set(UNDEFINED_CHILD_VALUE root_defined_after)
]=])
string(CONFIGURE "${_tip_root}" _tip_root @ONLY)
file(WRITE "${_tip_source}/CMakeLists.txt" "${_tip_root}")

# The same export spans directories with different headers, libraries, resources, and executable destinations.
foreach(_tip_child IN ITEMS a b)
  set(_tip_child_project
      [=[
project(Child_@_tip_child@ VERSION 1.2.3 LANGUAGES CXX)
set(CMAKE_INSTALL_LIBDIR "@_tip_child@/libraries")
set(CMAKE_INSTALL_BINDIR "@_tip_child@/executables")
set(CMAKE_INSTALL_INCLUDEDIR "@_tip_child@/headers")
set(CMAKE_INSTALL_DATADIR "@_tip_child@/data")
set(CHILD_TOKEN "child;value")
add_library(lib_@_tip_child@ STATIC value.cpp)
set_target_properties(lib_@_tip_child@ PROPERTIES PUBLIC_HEADER "$<$<CONFIG:Release>:public.hpp>;$<1:OFF>;$<1:0>;$<$<CONFIG:Debug>:debug-only.hpp>" PRIVATE_HEADER private.hpp RESOURCE resource.txt)
add_executable(run_@_tip_child@ main.cpp)
target_link_libraries(run_@_tip_child@ PRIVATE lib_@_tip_child@)
set(_template_args)
if("@_tip_child@" STREQUAL "a")
  list(APPEND _template_args CONFIG_TEMPLATE config.cmake.in)
endif()
function(register_child)
  set(PACKAGE_VENDOR "child_vendor")
  set(TEMPLATE "caller_template")
  string(CONCAT NESTED_TOKEN "@" "PROJECT_NAME" "@")
  set(options "caller_options")
  set(oneValueArgs "caller_one_values")
  set(TARGET_NAME "caller_target_name")
  set(EXPORT_PROPERTY_PREFIX "caller_export_prefix")
  target_install_package(lib_@_tip_child@ EXPORT_NAME Group CMAKE_CONFIG_DESTINATION common/cmake/Group ADDITIONAL_TARGETS run_@_tip_child@ ${_template_args})

  add_library(direct_@_tip_child@ INTERFACE)
  target_prepare_package(direct_@_tip_child@ CONFIG_TEMPLATE ../a/config.cmake.in)
endfunction()
register_child()
set(CHILD_TOKEN changed_after_registration)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/artifact-names.cmake" "set(LIBRARY_NAME ${CMAKE_STATIC_LIBRARY_PREFIX}lib_@_tip_child@${CMAKE_STATIC_LIBRARY_SUFFIX})\nset(EXECUTABLE_NAME run_@_tip_child@${CMAKE_EXECUTABLE_SUFFIX})\n")
]=])
  string(CONFIGURE "${_tip_child_project}" _tip_child_project @ONLY)
  file(WRITE "${_tip_source}/${_tip_child}/CMakeLists.txt" "${_tip_child_project}")
  file(WRITE "${_tip_source}/${_tip_child}/value.cpp" "int value_${_tip_child}() { return 42; }\n")
  file(WRITE "${_tip_source}/${_tip_child}/main.cpp" "int value_${_tip_child}(); int main() { return value_${_tip_child}() == 42 ? 0 : 1; }\n")
  foreach(_tip_file IN ITEMS public.hpp private.hpp resource.txt OFF 0 debug-only.hpp)
    file(WRITE "${_tip_source}/${_tip_child}/${_tip_file}" "${_tip_child}/${_tip_file}\n")
  endforeach()
endforeach()

file(
  WRITE "${_tip_source}/a/config.cmake.in"
  [=[
@PACKAGE_INIT@
@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@
set(REGISTERED_PROJECT "@PROJECT_NAME@")
set(REGISTERED_TOKEN "@CHILD_TOKEN@")
set(REGISTERED_UNDEFINED "@UNDEFINED_CHILD_VALUE@")
set(CALLER_TEMPLATE "@TEMPLATE@")
set(CALLER_PACKAGE_VENDOR "@PACKAGE_VENDOR@")
set(CALLER_LITERAL_TOKEN "@NESTED_TOKEN@")
set(CALLER_OPTIONS "@options@")
set(CALLER_ONE_VALUES "@oneValueArgs@")
set(CALLER_TARGET_NAME "@TARGET_NAME@")
set(CALLER_EXPORT_PREFIX "@EXPORT_PROPERTY_PREFIX@")
include("${CMAKE_CURRENT_LIST_DIR}/@ARG_EXPORT_NAME@Targets.cmake")
]=])
_tip_proof_run_step(
  NAME
  context-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source}"
  -B
  "${_tip_build}"
  -DCMAKE_BUILD_TYPE=Release
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  context-build
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  context-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build}"
  --config
  Release
  --prefix
  "${_tip_install}")

foreach(_tip_child IN ITEMS a b)
  include("${_tip_build}/${_tip_child}/artifact-names.cmake")
  _tip_proof_assert_exists("${_tip_install}/${_tip_child}/libraries/${LIBRARY_NAME}")
  _tip_proof_assert_exists("${_tip_install}/${_tip_child}/executables/${EXECUTABLE_NAME}")
  _tip_proof_assert_file_contains("${_tip_install}/${_tip_child}/headers/public.hpp" "${_tip_child}/public.hpp")
  _tip_proof_assert_file_contains("${_tip_install}/${_tip_child}/headers/OFF" "${_tip_child}/OFF")
  _tip_proof_assert_file_contains("${_tip_install}/${_tip_child}/headers/0" "${_tip_child}/0")
  _tip_proof_assert_not_exists("${_tip_install}/${_tip_child}/headers/debug-only.hpp")
  _tip_proof_assert_file_contains("${_tip_install}/${_tip_child}/headers/private.hpp" "${_tip_child}/private.hpp")
  _tip_proof_assert_file_contains("${_tip_install}/${_tip_child}/data/resource.txt" "${_tip_child}/resource.txt")
endforeach()
set(_tip_config "${_tip_install}/common/cmake/Group/GroupConfig.cmake")
_tip_proof_assert_file_contains("${_tip_config}" "set(REGISTERED_PROJECT \"Child_a\")")
_tip_proof_assert_file_contains("${_tip_config}" "set(REGISTERED_TOKEN \"child;value\")")
_tip_proof_assert_file_contains("${_tip_config}" "set(REGISTERED_UNDEFINED \"\")")
_tip_proof_assert_file_contains("${_tip_config}" "\${CMAKE_CURRENT_LIST_DIR}/GroupTargets.cmake")

# Both public entrypoints preserve caller variables whose names match implementation locals.
foreach(_tip_caller_config IN ITEMS "${_tip_config}" "${_tip_install}/a/data/cmake/direct_a/direct_aConfig.cmake" "${_tip_install}/b/data/cmake/direct_b/direct_bConfig.cmake")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_TEMPLATE \"caller_template\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_PACKAGE_VENDOR \"child_vendor\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_LITERAL_TOKEN \"@PROJECT_NAME@\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_OPTIONS \"caller_options\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_ONE_VALUES \"caller_one_values\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_TARGET_NAME \"caller_target_name\")")
  _tip_proof_assert_file_contains("${_tip_caller_config}" "set(CALLER_EXPORT_PREFIX \"caller_export_prefix\")")
endforeach()

# Loading the installed grouped export verifies every imported target resolves to a real artifact.
file(
  WRITE "${_tip_case_root}/consumer/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(Consumer LANGUAGES CXX)
find_package(Group 1.2.3 REQUIRED CONFIG)
foreach(name IN ITEMS lib_a run_a lib_b run_b)
  if(NOT TARGET "Group::${name}")
    message(FATAL_ERROR "Missing grouped target ${name}")
  endif()
endforeach()
]=])
_tip_proof_run_step(
  NAME
  context-consumer
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_case_root}/consumer"
  -B
  "${_tip_case_root}/consumer-build"
  "-DGroup_DIR=${_tip_install}/common/cmake/Group"
  ${_tip_toolchain_args})

# Two explicit template registrations cannot silently select different child substitutions.
file(APPEND "${_tip_source}/b/CMakeLists.txt" "target_install_package(lib_b EXPORT_NAME Group CMAKE_CONFIG_DESTINATION common/cmake/Group CONFIG_TEMPLATE ../a/config.cmake.in)\n")
_tip_proof_expect_failure(
  NAME
  template-context-conflict
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source}"
  -B
  "${_tip_case_root}/conflict-build"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "Conflicting CONFIG_TEMPLATE substitution")
