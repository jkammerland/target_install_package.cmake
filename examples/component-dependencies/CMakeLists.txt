cmake_minimum_required(VERSION 3.25)

project(component_dependencies_example VERSION 2.1.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core game engine library (always available)
add_library(game_engine SHARED)
target_sources(game_engine PRIVATE src/core.cpp)

# Declare public headers using FILE_SET
target_sources(game_engine PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES 
    "include/game_engine/core.h"
    "include/game_engine/graphics.h"
    "include/game_engine/audio.h"
    "include/game_engine/networking.h"
)

# Set C++ standard
target_compile_features(game_engine PUBLIC cxx_std_17)

# Create mock dependency targets (to avoid requiring actual dependencies)
# In real projects, these would be found via find_package()
add_library(MockOpenGL INTERFACE)
add_library(MockGLFW INTERFACE) 
add_library(MockAudioFramework INTERFACE)
add_library(MockBoost INTERFACE)

# Alias them to simulate real packages (but don't link - saves build time)
add_library(OpenGL::GL ALIAS MockOpenGL)
add_library(glfw ALIAS MockGLFW)
add_library(AudioFramework::AudioFramework ALIAS MockAudioFramework)
add_library(Boost::system ALIAS MockBoost)

# Install the library with component-dependent dependencies
target_install_package(game_engine
  NAMESPACE GameEngine::
  VERSION ${PROJECT_VERSION}
  # Package global dependencies (always loaded)
  PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED"
  # Component-specific dependencies (pairs: component name, dependencies)
  COMPONENT_DEPENDENCIES
    "graphics" "OpenGL 4.5 REQUIRED"
    "audio" "AudioFramework 2.1 REQUIRED"
    "networking" "Boost 1.79 REQUIRED COMPONENTS system network"
)