# Component Prefix Pattern Example

This example demonstrates the **Component Prefix Pattern** (v6.0) for logical component grouping with shared exports and predictable naming.

## Features Demonstrated

- **Component Prefix Pattern**: `COMPONENT="Core"` creates `Core` (runtime), `Core_Development` (development)
- **Logical Grouping**: Multiple targets share the same logical component group
- **Shared Export**: All targets packaged under single `MediaLib` export
- **Mixed Target Types**: Shared library, static library, and executable
- **Selective Installation**: Install specific logical groups or individual components

## Architecture

```
MediaLib Package (shared export with Component Prefix Pattern):
├── Core             → libmedia_core.so (shared library runtime files) 
├── Core_Development → headers + libmedia_dev_tools.a (development files from both Core targets)
├── Tools            → asset_converter (executable runtime)
├── Tools_Development → (empty - executables typically have no dev files)
└── Development      → MediaLib CMake config files (shared across all targets)
```

The Component Prefix Pattern creates predictable component names: `{COMPONENT}` for runtime, `{COMPONENT}_Development` for development.

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build all targets
cmake --build .
```

### Step 2: Component-Based Installation

#### Install All Components

```bash
# Install everything - all logical groups
cmake --install .
```

#### Install Core Logical Group

```bash
# Install only Core runtime files (end-user deployment)
cmake --install . --component Core

# Install only Core development files (headers + static libs)  
cmake --install . --component Core_Development

# Install both Core runtime and development
cmake --install . --component Core
cmake --install . --component Core_Development
```

#### Install Tools Logical Group  

```bash
# Install only Tools runtime (executable)
cmake --install . --component Tools

# Tools typically have no development component (Tools_Development would be empty)
```

#### Install CMake Configuration

```bash
# Install shared CMake config files (needed for find_package)
cmake --install . --component Development
```

#### Deployment Scenarios

```bash
# Minimal runtime deployment (libraries + tools)
cmake --install . --component Core
cmake --install . --component Tools

# Full development setup (runtime + development + cmake configs)  
cmake --install . --component Core
cmake --install . --component Core_Development
cmake --install . --component Tools  
cmake --install . --component Development
```

### Step 3: Verify Installation

#### Full Installation Structure

```
install/
├── bin/
│   └── asset_converter                    # Tools
├── include/
│   └── media/
│       ├── core.h                        # Core_Development  
│       └── dev_tools.h                   # Core_Development
├── lib64/
│   ├── libmedia_core.so.6.0.1           # Core
│   ├── libmedia_core.so.5                # Core  
│   ├── libmedia_core.so                  # Core (dev symlink)
│   └── libmedia_dev_tools.a              # Core_Development
└── share/
    └── cmake/
        └── MediaLib/                      # Development (shared)
            ├── MediaLib.cmake
            ├── MediaLib-noconfig.cmake  
            ├── MediaLibConfig.cmake
            └── MediaLib-config-version.cmake
```

#### Component-Specific Installation Examples

**Core Runtime Only** (minimal deployment):
```
install/lib64/libmedia_core.so.6.0.1
```

**Tools Runtime Only**:
```
install/bin/asset_converter
```

**Core Development Only**: 
```
install/include/media/core.h
install/include/media/dev_tools.h  
install/lib64/libmedia_dev_tools.a
```

## Component Details

### Core Logical Group

**Core**: Contains runtime files for the Core logical group
- Shared libraries: `libmedia_core.so.*`
- No headers or development files  
- Minimal footprint for deployment

**Core_Development**: Contains development files for the Core logical group
- Headers from both `media_core` and `media_dev_tools`
- Static libraries: `libmedia_dev_tools.a`
- Development symlinks for shared libraries
- No CMake config files (those are shared)

### Tools Logical Group

**Tools**: Contains runtime files for the Tools logical group
- Executables: `asset_converter`
- Independent from Core logical group

**Tools_Development**: Typically empty for executable-only logical groups
- Executables rarely have development artifacts

### Shared Components

**Development**: Contains shared files across all logical groups
- CMake configuration files for `MediaLib` package
- Required for `find_package(MediaLib)` to work
- Independent of specific logical groups

## Using the Installed Package

### Consumer Usage

```cmake
# CMakeLists.txt  
cmake_minimum_required(VERSION 3.25)
project(media_app)

# Find the unified MediaLib package
find_package(MediaLib REQUIRED)

add_executable(my_app main.cpp)

# Link against targets from different logical groups
target_link_libraries(my_app PRIVATE 
  Media::media_core        # From Core logical group
  Media::media_dev_tools   # From Core logical group  
  # Media::asset_converter is an executable, not linkable
)
```

### Available Targets

The `MediaLib` package provides these targets:

- `Media::media_core` - Shared library from Core logical group
- `Media::media_dev_tools` - Static library from Core logical group  
- `Media::asset_converter` - Executable from Tools logical group (not linkable)

**Key Insight**: The consumer doesn't need to know about components - `find_package(MediaLib)` provides all targets. Components are purely for installation control.

### Consumer Usage example

```cpp
// main.cpp
#include "media/core.h"
#ifdef MEDIA_DEV_TOOLS_AVAILABLE
#include "media/dev_tools.h"
#endif

int main() {
    // Initialize media system
    if (!media::MediaCore::initialize()) {
        return 1;
    }
    
    // Load and play media
    media::MediaCore::loadMedia("song.mp3", media::MediaType::AUDIO);
    media::MediaCore::playAudio("song.mp3");
    
#ifdef MEDIA_DEV_TOOLS_AVAILABLE
    // Use development tools if available
    auto info = media::DevTools::analyzeFile("song.mp3");
    std::cout << "Duration: " << info.duration << " seconds" << std::endl;
#endif
    
    media::MediaCore::shutdown();
    return 0;
}
```

## Asset Converter Tool

The installed tool provides media conversion capabilities:

```bash
# Basic usage (if Tools_Runtime component is installed)
./install/bin/asset_converter input.wav output.mp3

# With options
./install/bin/asset_converter -f mp3 -q 95 input.wav output.mp3

# Help
./install/bin/asset_converter --help
```

## Component Prefix Pattern Features

- **Predictable Naming**: `COMPONENT="Core"` always creates `Core` (runtime), `Core_Development` (development)
- **Logical Grouping**: Multiple targets (`media_core`, `media_dev_tools`) share the same logical group (`Core`)
- **Shared Export**: All targets packaged under unified `MediaLib` export  
- **No Dual Install Complexity**: Each target installs to exactly one runtime and one development component
- **Mixed Target Types**: Handles shared libs, static libs, and executables uniformly

This example demonstrates the Component Prefix Pattern for logical component organization with predictable naming and clean separation.