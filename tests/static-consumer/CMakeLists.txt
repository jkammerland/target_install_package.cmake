cmake_minimum_required(VERSION 3.25)
project(installed_static_consumer LANGUAGES CXX)

# This fresh project intentionally does not find fmt before loading the package.
find_package(my_static_package CONFIG REQUIRED)
add_executable(static_consumer main.cpp)
target_link_libraries(static_consumer PRIVATE my_static_package::static1 my_static_package::static2)

enable_testing()
add_test(NAME static_symbols COMMAND static_consumer)
