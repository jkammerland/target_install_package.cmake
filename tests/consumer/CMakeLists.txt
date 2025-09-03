cmake_minimum_required(VERSION 3.23)
project(consumer_test VERSION 1.0.0)

# This is a consumer test that demonstrates how to use the installed target_install_package
# It will test that our package is properly findable and usable

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Try to find our installed package (which provides target_install_package functions)
find_package(target_install_package REQUIRED)

# Test that we can use the installed utilities
if(NOT COMMAND target_install_package)
    message(FATAL_ERROR "target_install_package command not available after find_package")
endif()

message(STATUS "✓ Found target_install_package successfully")

# Create a simple executable for testing
add_executable(consumer main.cpp)
target_compile_features(consumer PUBLIC cxx_std_17)

# Test using target_install_package on our consumer executable
target_install_package(consumer 
    NAMESPACE Consumer::
    VERSION ${PROJECT_VERSION})

message(STATUS "✓ Consumer test configured successfully")