vcpkg_minimum_required(VERSION 2024-01-10)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

file(REAL_PATH "${CURRENT_PORT_DIR}/../../../../" TIP_SOURCE_ROOT)

if(NOT EXISTS "${TIP_SOURCE_ROOT}/CMakeLists.txt")
  message(FATAL_ERROR "Expected repository root at ${TIP_SOURCE_ROOT}, but CMakeLists.txt was not found")
endif()

vcpkg_cmake_configure(
  SOURCE_PATH "${TIP_SOURCE_ROOT}"
  OPTIONS
    -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON
    -DTARGET_INSTALL_PACKAGE_DISABLE_INSTALL=OFF
    -Dtarget_install_package_BUILD_TESTS=OFF
)

vcpkg_cmake_install()

# This port ships only CMake scripts/config, so the debug tree is redundant.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

# Match vcpkg documentation conventions.
file(INSTALL "${TIP_SOURCE_ROOT}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)
