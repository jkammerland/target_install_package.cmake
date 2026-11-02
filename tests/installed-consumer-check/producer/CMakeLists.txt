cmake_minimum_required(VERSION 3.25)
project(
  consumer_check_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

include("${TIP_REPO_ROOT}/target_install_package.cmake")

# A distinct imported dependency makes missing find_dependency calls observable.
add_library(tip_check_dependency::value INTERFACE IMPORTED)
set_target_properties(tip_check_dependency::value PROPERTIES INTERFACE_COMPILE_DEFINITIONS "DEPENDENCY_VALUE=42")
install(
  FILES dependency-config.cmake
  DESTINATION share/cmake/tip_check_dependency
  RENAME tip_check_dependencyConfig.cmake)

add_library(answer STATIC answer.cpp)
target_sources(answer PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}" FILES answer.hpp)
target_link_libraries(answer PRIVATE tip_check_dependency::value)

# A rooted dependency must remain discoverable with the toolchain's package policy.
set(_tip_dependencies "tip_check_dependency CONFIG")
if(TIP_REQUIRE_ROOTED_DEPENDENCY)
  find_package(tip_check_rooted CONFIG REQUIRED)
  target_link_libraries(answer PRIVATE tip_check_rooted::value)
  list(APPEND _tip_dependencies "tip_check_rooted CONFIG")
endif()

if(TIP_BROKEN_RELOCATION)
  target_include_directories(answer INTERFACE "$<INSTALL_INTERFACE:${CMAKE_INSTALL_PREFIX}/include>")
endif()

if(TIP_BROKEN_DEPENDENCY)
  target_install_package(answer)
else()
  target_install_package(answer PUBLIC_DEPENDENCIES ${_tip_dependencies})
endif()
