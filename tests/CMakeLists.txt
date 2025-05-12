project(tests VERSION 1.0.0)

add_library(static2 STATIC)
target_sources(static2 PRIVATE src2.cpp)
target_include_directories(static2 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_definitions(static2 PUBLIC "STATIC=1")
target_install_package(static2 EXPORT_NAME "my_static_package")

add_library(static1 STATIC)
target_sources(static1 PRIVATE src1.cpp)
target_include_directories(static1 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_definitions(static1 PUBLIC "STATIC=1")
# Declare public headers for static1 Using FILE_SET (CMake 3.23+)
target_sources(static1 PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/tests/header.h")

# Link static2 to static1
target_link_libraries(static1 PRIVATE static2)

# target_install_package(static1 ADDITIONAL_TARGETS static2)
target_install_package(static1 EXPORT_NAME "my_static_package")

add_library(shared1 SHARED)
target_sources(shared1 PRIVATE src1.cpp)
target_include_directories(shared1 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_definitions(shared1 PRIVATE "SHARED=1") # PRIVATE FOR TESTING
target_install_package(shared1)

add_library(interface1 INTERFACE)
target_include_directories(interface1 INTERFACE include)
target_compile_definitions(interface1 INTERFACE "INTERFACE=1")

add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE static1 shared1 interface1)
target_compile_definitions(${PROJECT_NAME} PRIVATE "SHARED=1") # Need to re-enable because it is PRIVATE above
target_install_package(${PROJECT_NAME})
