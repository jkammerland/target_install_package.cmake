project(tests VERSION 1.0.0)

project_log(VERBOSE "HELLO")

add_library(static1 STATIC)
target_sources(static1 PRIVATE src1.cpp)
target_include_directories(static1 PUBLIC include)
target_compile_definitions(static1 PUBLIC "STATIC=1")

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
