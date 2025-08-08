# CPack Basic Integration Example

This example demonstrates automatic CPack configuration using `export_cpack()` with `target_install_package()`.

## Features Demonstrated

- Automatic CPack setup with smart defaults
- Component-based packaging
- Cross-platform package generation
- Integration with target_install_package components

## Architecture

```
MyLibrary Package Components:
├── Runtime/      → mylib (shared library)
├── Development/  → mylib headers + mylib_utils + CMake configs
└── Tools/        → mytool (executable)
```

## Building and Testing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix
cmake .. -DCMAKE_INSTALL_PREFIX=./install

# Build all targets
cmake --build .
```

### Step 2: Test Installation

```bash
# Install all components
cmake --install .

# Verify installation structure
find install/ -type f | sort
```

### Step 3: Generate Packages

```bash
# Generate all configured package types
cpack

# Generate specific package type
cpack -G TGZ

# Generate component packages (if supported)
cpack -G TGZ -D CPACK_ARCHIVE_COMPONENT_INSTALL=ON
```

### Step 4: Test Generated Packages

```bash
# List generated packages
ls -la *.tar.gz *.zip *.deb *.rpm 2>/dev/null || echo "No packages found"

# Extract and verify package contents
tar -tzf MyLibrary-*.tar.gz | head -20
```

## CPack Configuration

The example uses `export_cpack()` with these settings:

```cmake
export_cpack(
  PACKAGE_NAME "MyLibrary"
  PACKAGE_VENDOR "Example Corp"
  PACKAGE_CONTACT "support@example.com"
  PACKAGE_HOMEPAGE_URL "https://example.com/mylib"
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)
```

### Auto-Detected Settings

- **Components**: Automatically detected from target_install_package calls
  - `Runtime` (from mylib shared library)
  - `Development` (from mylib headers and mylib_utils)
  - `Tools` (from mytool executable)

- **Generators**: Platform-specific defaults
  - Linux: `TGZ`, `DEB`, `RPM`
  - Windows: `TGZ`, `ZIP`, `WIX` (if available)
  - macOS: `TGZ`, `DragNDrop`

- **Component Dependencies**: Automatically configured
  - `Development` depends on `Runtime`

## Package Types Generated

### Universal Archive (TGZ/ZIP)

- Cross-platform compatibility
- Contains all components by default
- Can be component-split with `-D CPACK_ARCHIVE_COMPONENT_INSTALL=ON`

### Linux Packages (DEB/RPM)

- Native package management integration
- Automatic dependency handling
- Component-based installation support

### Windows Installer (WIX)

- Professional Windows installer
- Component selection UI
- Registry integration and uninstall support

## Component Installation Examples

### Runtime Only (End Users)

```bash
# Extract only runtime files
cmake --install . --component Runtime

# Result: Only shared libraries needed to run applications
install/
└── lib/
    ├── libmylib.so.1.2.0
    ├── libmylib.so.1
    └── libmylib.so
```

### Development Package (Developers)

```bash
# Install development files
cmake --install . --component Development

# Result: Headers, static libs, CMake configs
install/
├── include/
│   └── mylib/
│       ├── core.h
│       └── utils.h
├── lib/
│   └── libmylib_utils.a
└── share/
    └── cmake/
        ├── mylib/
        └── mylib_utils/
```

### Tools Package

```bash
# Install command-line tools
cmake --install . --component Tools

# Result: Executable tools
install/
└── bin/
    └── mytool
```

## Testing the Packages

### Verify Package Contents

```bash
# For TGZ packages
tar -tzf MyLibrary-1.2.0-Linux.tar.gz

# For component packages (if generated)
tar -tzf MyLibrary-1.2.0-Linux-Runtime.tar.gz
tar -tzf MyLibrary-1.2.0-Linux-Development.tar.gz
tar -tzf MyLibrary-1.2.0-Linux-Tools.tar.gz
```

### Test Package Installation

```bash
# Extract package to test location
mkdir test-install
cd test-install
tar -xzf ../MyLibrary-1.2.0-Linux.tar.gz

# Verify the tool works
./bin/mytool --version
./bin/mytool --help
```

### Consumer Project Test

Create a simple consumer to test the package:

```cmake
# consumer/CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Point to package installation
list(APPEND CMAKE_PREFIX_PATH "/path/to/test-install")

find_package(mylib REQUIRED)
find_package(mylib_utils REQUIRED)

add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE MyLib::mylib MyLib::mylib_utils)
```

```cpp
// consumer/main.cpp
#include "mylib/core.h"
#include "mylib/utils.h"
#include <iostream>

int main() {
    mylib::Core::initialize();
    
    auto parts = mylib::Utils::split("hello,world,test", ",");
    auto joined = mylib::Utils::join(parts, " | ");
    
    std::cout << "Result: " << joined << std::endl;
    
    mylib::Core::shutdown();
    return 0;
}
```

## Key Features

- **Zero-Configuration**: CPack works out-of-the-box with sensible defaults
- **Component Awareness**: Automatically detects and configures components
- **Cross-Platform**: Generates appropriate packages for each platform
- **Integration**: Seamlessly works with existing target_install_package usage

## Customization Options

You can override auto-detected settings:

```cmake
export_cpack(
  PACKAGE_NAME "CustomName"
  GENERATORS "ZIP;DEB"  # Override auto-detection
  COMPONENTS "Runtime;Tools"  # Subset of components
  NO_DEFAULT_GENERATORS  # Disable auto-detection
  ADDITIONAL_CPACK_VARS
    "CPACK_PACKAGE_EXECUTABLES" "mytool;MyTool"
    "CPACK_CREATE_DESKTOP_LINKS" "mytool"
)
```

This example shows how `export_cpack()` simplifies package creation while maintaining full flexibility.