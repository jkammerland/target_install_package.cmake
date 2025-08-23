cmake_minimum_required(VERSION 3.23)
project(rpath_control_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a simple library to demonstrate RPATH control
add_library(rpath_default_lib SHARED src/default_lib.cpp)
target_include_directories(rpath_default_lib PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Create headers using FILE_SET (modern CMake approach)
target_sources(rpath_default_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS include
    FILES include/rpath_example/default_lib.h
)

# Create another library with NO_DEFAULT_RPATH
add_library(rpath_disabled_lib SHARED src/disabled_lib.cpp)
target_include_directories(rpath_disabled_lib PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_sources(rpath_disabled_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS include  
    FILES include/rpath_example/disabled_lib.h
)

# Create a library with user-configured RPATH (should be preserved)
add_library(rpath_user_lib SHARED src/user_lib.cpp)
target_include_directories(rpath_user_lib PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_sources(rpath_user_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS include
    FILES include/rpath_example/user_lib.h
)

# User sets custom RPATH (should be preserved)
set_target_properties(rpath_user_lib PROPERTIES
    INSTALL_RPATH "/custom/user/path:/another/path"
)

# Install with default RPATH behavior
target_install_package(rpath_default_lib
    EXPORT_NAME rpath_control
    NAMESPACE RPathExample::
    ALIAS_NAME default
)

# Install with NO_DEFAULT_RPATH 
target_install_package(rpath_disabled_lib
    EXPORT_NAME rpath_control
    NAMESPACE RPathExample::
    ALIAS_NAME disabled
    NO_DEFAULT_RPATH
)

# Install with user-configured RPATH (should preserve user setting)
target_install_package(rpath_user_lib
    EXPORT_NAME rpath_control
    NAMESPACE RPathExample::
    ALIAS_NAME custom
)

# Create a simple executable to test linkage
add_executable(rpath_test_app src/main.cpp)
target_link_libraries(rpath_test_app PRIVATE 
    rpath_default_lib 
    rpath_disabled_lib 
    rpath_user_lib
)

# Install the test app
install(TARGETS rpath_test_app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT Runtime
)