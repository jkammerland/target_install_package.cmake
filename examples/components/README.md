# Component-Based Installation Example

This example demonstrates advanced component-based installation using custom component names and selective installation strategies.

## Features Demonstrated

- Custom component names instead of defaults
- Mixed library types (shared, static, executable)
- Component validation with `SUPPORTED_COMPONENTS`
- Selective installation workflows
- Shared export between different targets

## Architecture

```
Media Package Components:
├── runtime/     → media_core (shared library)
├── devel/       → media_core headers + media_dev_tools (static library)
└── tools/       → asset_converter (executable)
```

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
# Install everything
cmake --install .
```

#### Install Only Runtime Components

```bash
# Install only what end-users need to run applications
cmake --install . --component runtime
```

#### Install Development Components

```bash
# Install headers, static libraries, and CMake configs
cmake --install . --component devel
```

#### Install Developer Tools

```bash
# Install command-line tools
cmake --install . --component tools
```

#### Combined Installation

```bash
# Install runtime + development (typical developer setup)
cmake --install . --component runtime --component devel
```

### Step 3: Verify Installation

#### Full Installation Structure

```
install/
├── bin/
│   └── asset_converter          # tools component
├── include/
│   └── media/
│       ├── core.h              # devel component
│       └── dev_tools.h         # devel component
├── lib/
│   ├── libmedia_core.so.1.0.0  # runtime component
│   ├── libmedia_core.so.1       # runtime component
│   ├── libmedia_core.so         # devel component (dev symlink)
│   └── libmedia_dev_tools.a     # devel component
└── share/
    └── cmake/
        ├── media_core/          # devel component
        │   ├── media_core-config.cmake
        │   ├── media_core-config-version.cmake
        │   └── media_core-targets.cmake
        └── asset_converter/     # tools component
            ├── asset_converter-config.cmake
            ├── asset_converter-config-version.cmake
            └── asset_converter-targets.cmake
```

#### Runtime-Only Installation

```
install/
└── lib/
    ├── libmedia_core.so.1.0.0
    └── libmedia_core.so.1
```

## Component Details

### Runtime Component (`runtime`)

Contains only what's needed to run applications:
- Shared libraries (`.so`, `.dll`)
- No headers or development files
- Minimal footprint for deployment

### Development Component (`devel`)

Contains everything developers need:
- Headers for both libraries
- Static libraries
- Development symlinks for shared libraries
- CMake configuration files

### Tools Component (`tools`)

Contains command-line utilities:
- Asset converter executable
- Independent from core library components

## Using the Installed Package

### Consumer for Runtime Library

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(media_app)

# Find the runtime library
find_package(media_core REQUIRED COMPONENTS core)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE Media::media_core)
```

### Consumer with Component Validation

The package defines supported components, so invalid requests will fail:

```cmake
# This works - 'core' is supported
find_package(media_core REQUIRED COMPONENTS core)

# This fails - 'graphics' is not in SUPPORTED_COMPONENTS
find_package(media_core REQUIRED COMPONENTS graphics)  # ERROR!
```

### Advanced Consumer Usage

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

## Component Strategy Benefits

### Deployment Flexibility

- **Small Runtime**: Deploy only shared libraries for production
- **Full Development**: Install everything for developers
- **Tool Distribution**: Distribute utilities independently

### Package Management

- Different components can be in separate packages
- Users install only what they need
- Reduced storage and bandwidth requirements

### Validation

- `SUPPORTED_COMPONENTS` prevents typos and invalid requests
- Clear component boundaries and expectations
- Better error messages for misconfiguration

## Asset Converter Tool

The installed tool provides media conversion capabilities:

```bash
# Basic usage
./install/bin/asset_converter input.wav output.mp3

# With options
./install/bin/asset_converter -f mp3 -q 95 input.wav output.mp3

# Help
./install/bin/asset_converter --help
```

## Key Features

- **Custom Components**: Uses `runtime`, `devel`, `tools` instead of defaults
- **Component Validation**: `SUPPORTED_COMPONENTS` validates consumer requests
- **Shared Exports**: `media_dev_tools` shares export with `media_core`
- **Mixed Target Types**: Handles shared libs, static libs, and executables

## Key Files

- **CMakeLists.txt**: Component configuration and validation
- **include/media/**: Public API headers
- **src/**: Implementation files
- **asset_converter**: Standalone tool implementation

This example demonstrates production-ready component-based packaging strategies.