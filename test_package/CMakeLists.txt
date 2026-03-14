cmake_minimum_required(VERSION 3.25)

project(conan_test_package LANGUAGES CXX)

find_package(target_install_package CONFIG REQUIRED)

add_executable(test_package main.cpp)
target_compile_features(test_package PRIVATE cxx_std_17)
target_install_package(test_package NAMESPACE ConanTest:: VERSION 0.1.0)
