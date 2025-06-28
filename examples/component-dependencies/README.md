# Component Dependencies Example

This example demonstrates how to use `COMPONENT_DEPENDENCIES` to specify dependencies that are only loaded when specific components are requested by consumers.

## Project Structure

```
component-dependencies/
├── include/game_engine/
│   ├── core.h          # Core functionality (always available)
│   ├── graphics.h      # Graphics component 
│   ├── audio.h         # Audio component
│   └── networking.h    # Networking component
├── src/
│   └── core.cpp        # Core implementation
└── CMakeLists.txt      # Build configuration
```

## Component Dependencies

The `game_engine` library defines component-dependent dependencies:

- **Package Global**: `fmt 10.0.0 REQUIRED` (always loaded)
- **graphics**: `OpenGL 4.5 REQUIRED; glfw3 3.3 REQUIRED`
- **audio**: `AudioFramework 2.1 REQUIRED`
- **networking**: `Boost 1.79 REQUIRED COMPONENTS system network`

## Consumer Usage Examples

### Basic Usage (Core Only)
```cmake
find_package(game_engine REQUIRED)
target_link_libraries(my_app PRIVATE GameEngine::game_engine)
# Only loads: fmt
```

### Graphics Component
```cmake
find_package(game_engine REQUIRED COMPONENTS graphics)
target_link_libraries(my_app PRIVATE GameEngine::game_engine)
# Loads: fmt + OpenGL + glfw3
```

### Multiple Components
```cmake
find_package(game_engine REQUIRED COMPONENTS graphics audio networking)
target_link_libraries(my_app PRIVATE GameEngine::game_engine)
# Loads: fmt + OpenGL + glfw3 + AudioFramework + Boost
```

## Building the Example

```bash
cd examples/component-dependencies
mkdir build && cd build
cmake ..
cmake --build .
cmake --install . --prefix /path/to/install
```

## Generated Config File

The generated `game_engine-config.cmake` will contain:

```cmake
# Component-dependent dependencies
if(game_engine_FIND_COMPONENTS AND "graphics:OpenGL 4.5 REQUIRED;glfw3 3.3 REQUIRED;audio:AudioFramework 2.1 REQUIRED;networking:Boost 1.79 REQUIRED COMPONENTS system network")
  # Component dependency resolution logic
endif()

# Package global dependencies (always loaded regardless of components)
find_dependency(fmt 10.0.0 REQUIRED)
```

This ensures that:
1. **fmt** is always loaded when finding the package
2. **Component-specific dependencies** are only loaded when their component is requested
3. **Multiple components** can be requested simultaneously
4. **Backward compatibility** is maintained for consumers not using components