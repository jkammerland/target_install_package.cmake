cmake_minimum_required(VERSION 3.25)
project(installed_answer_consumer LANGUAGES CXX)

find_package(answer CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE answer::answer)
if(TIP_EXPECT_EMULATOR)
  target_compile_definitions(consumer PRIVATE TIP_EXPECT_EMULATOR)
endif()

if(NOT TIP_NO_TESTS)
  enable_testing()
  add_test(NAME answer COMMAND consumer)
endif()
