# Multi-Target Packaging Example

This example demonstrates packaging multiple related libraries together using `ADDITIONAL_TARGETS` with `target_install_package`.

## Features Demonstrated

- Multiple static libraries in one package
- Dependency relationships between targets
- Single package export for multiple libraries
- Hierarchical namespace organization
- Utility library pattern

## Architecture

```
game_engine (main library)
├── core_utils (logging, configuration)
└── math_ops (mathematical operations)
```

The `game_engine` library depends on both `core_utils` and `math_ops`, and all three are packaged together.

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build all libraries
cmake --build .
```

### Step 2: Install the Package

```bash
# Install the complete package
cmake --install .
```

### Step 3: Verify Installation

After installation, you should see the following structure in `build/install/`:

```
install/
├── include/
│   ├── core/
│   │   ├── logging.h
│   │   └── config.h
│   ├── math/
│   │   └── operations.h
│   └── engine/
│       ├── engine.h
│       └── api.h
├── lib/
│   ├── libcore_utils.a
│   ├── libmath_ops.a
│   └── libgame_engine.a
└── share/
    └── cmake/
        └── game_engine/
            ├── game_engine-config.cmake
            ├── game_engine-config-version.cmake
            └── game_engine-targets.cmake
```

## Library Components

### Core Utilities (`core_utils`)

Provides fundamental services:
- **Logging**: Multi-level logging system (DEBUG, INFO, WARNING, ERROR)
- **Configuration**: Key-value configuration management

### Math Operations (`math_ops`)

Provides mathematical functions:
- Power and square root calculations
- Factorial computation
- Prime number testing
- GCD and LCM operations

### Game Engine (`game_engine`)

Main library that orchestrates core utilities and math operations:
- Engine initialization and lifecycle
- Frame rate management
- High-level API for easy usage

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(game_consumer)

# Find the package (automatically finds all targets)
find_package(game_engine 1.0 REQUIRED)

# Create executable
add_executable(my_game main.cpp)

# Link with the main library (dependencies are transitive)
target_link_libraries(my_game PRIVATE GameEngine::game_engine)

# Note: GameEngine::core_utils and GameEngine::math_ops are 
# automatically available through transitive dependencies
```

```cpp
// main.cpp
#include "engine/api.h"
#include "core/logging.h"
#include "math/operations.h"
#include <iostream>

int main() {
    // Set up logging
    core::Logger::setLevel(core::LogLevel::DEBUG);
    
    // Use math operations
    std::cout << "2^10 = " << math::Operations::power(2, 10) << std::endl;
    std::cout << "Is 17 prime? " << (math::Operations::isPrime(17) ? "Yes" : "No") << std::endl;
    
    // Initialize and run the engine
    if (engine::API::initializeEngine("game_config.conf")) {
        core::Logger::info("Game engine started successfully");
        
        // In a real game, you would call:
        // engine::API::runEngine();
    }
    
    engine::API::shutdownEngine();
    return 0;
}
```

## Package Benefits

### Single Find Operation
- One `find_package()` call gets all libraries
- Automatic dependency resolution
- Consistent versioning across all components

### Namespace Organization
- All targets use the `GameEngine::` namespace
- Clear hierarchy and relationships
- Prevents naming conflicts

### Simplified Distribution
- Single package to install and distribute
- Unified versioning and compatibility
- Reduced consumer configuration complexity

## Key Features

- **ADDITIONAL_TARGETS**: Packages `core_utils` and `math_ops` with `game_engine`
- **Transitive Dependencies**: Linking with `game_engine` automatically provides access to utilities
- **Unified Namespace**: All targets use `GameEngine::` prefix
- **Single Export**: All targets share the same CMake export file

## Key Files

- **CMakeLists.txt**: Multi-target configuration with dependencies
- **include/**: Hierarchical header organization
- **src/**: Implementation files for all libraries

This example shows how to create cohesive library packages with multiple related components.