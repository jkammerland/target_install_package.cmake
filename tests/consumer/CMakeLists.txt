cmake_minimum_required(VERSION 3.25)

project(consumer)

list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../build/install5")

find_package(component-devel CONFIG REQUIRED)
find_package(shared1 CONFIG REQUIRED)

add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE component-devel::component-devel)
