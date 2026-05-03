# CPack Basic Integration Example

This example demonstrates automatic CPack configuration using `export_cpack()` with `target_install_package()`.
Also see the [cpack-tutorial](../../CPack-Tutorial.md).

## Features Demonstrated

- Automatic CPack setup with smart defaults
- Component-based packaging
- Cross-platform package generation
- Integration with target_install_package components

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
  PACKAGE_VERSION "${PROJECT_VERSION}"
  PACKAGE_VENDOR "Example Corp"
  PACKAGE_CONTACT "support@example.com"
  PACKAGE_DESCRIPTION "${PROJECT_DESCRIPTION}"
  PACKAGE_HOMEPAGE_URL "https://example.com/cpack_lib"
  PACKAGE_LICENSE "MIT"
  LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../../LICENSE"
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)
```

`PACKAGE_LICENSE` supplies package-manager metadata such as the RPM `License:` field, while `LICENSE_FILE` sets CPack's license resource for generators that display or embed one. Install a license file explicitly, or use `ADDITIONAL_FILES`, when the license text must appear as a payload file in the installed tree.
`<libdir>` below resolves to the platform-appropriate library directory, typically `lib` or `lib64`.

### Auto-Detected Settings

- **Components**: Automatically detected from target_install_package calls
  - `Runtime` (from `cpack_lib`)
  - `Development` (from `cpack_lib` headers and `cpack_lib_utils`)
  - `Tools` (from mytool executable)

- **Generators**: Platform-specific defaults
  - Linux: `TGZ`, `DEB`, `RPM`
  - Windows: `TGZ`, `ZIP`, `WIX` (if available)
  - macOS: `TGZ`, `DragNDrop`

- **Component Dependencies**: Automatically configured
  - `Development` depends on `Runtime` and `Tools`

## Package Types Generated

### Universal Archive (TGZ/ZIP)

- Cross-platform compatibility
- Generates one archive per component when component install is enabled
- Keeps runtime, development, and tool payloads inspectable independently

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
└── <libdir>/
    ├── libcpack_lib.so.1.2.0
    └── libcpack_lib.so.1
```

### Development Package (Developers)

```bash
# Install SDK files
cmake --install . --component Development

# Result: Headers, static libs, shared-library namelinks, CMake configs.
# For manual component installs of shared libraries, install Runtime too before consuming.
install/
├── include/
│   └── cpack_lib/
│       ├── core.h
│       └── utils.h
├── <libdir>/
│   ├── libcpack_lib.so
│   └── libcpack_lib_utils.a
└── share/
    └── cmake/
        ├── cpack_lib/
        └── cpack_lib_utils/
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
# For component TGZ packages
tar -tzf MyLibrary-1.2.0-Linux-Runtime.tar.gz
tar -tzf MyLibrary-1.2.0-Linux-Development.tar.gz
tar -tzf MyLibrary-1.2.0-Linux-TOOLS.tar.gz
```

### Test Package Installation

```bash
# Extract runtime and tool packages to test location.
# Archive entries preserve the configured install prefix.
mkdir test-install
cd test-install
tar -xzf ../MyLibrary-1.2.0-Linux-Runtime.tar.gz
tar -xzf ../MyLibrary-1.2.0-Linux-TOOLS.tar.gz
package_prefix="$(dirname "$(dirname "$(find . -path '*/bin/mytool' -type f -print -quit)")")"

# Verify the tool works
"$package_prefix/bin/mytool" --version
"$package_prefix/bin/mytool" --help

# Add development payload before testing find_package consumers.
# Runtime was extracted above; package-manager installs get that dependency automatically.
tar -xzf ../MyLibrary-1.2.0-Linux-Development.tar.gz
```

### Consumer Project Test

Create a simple consumer to test the package:

```cmake
# consumer/CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Point to the extracted package prefix that contains bin/, include/, and share/
list(APPEND CMAKE_PREFIX_PATH "/path/to/test-install/<extracted-prefix>")

find_package(cpack_lib REQUIRED)
find_package(cpack_lib_utils REQUIRED)

add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE cpack_lib::cpack_lib cpack_lib::cpack_lib_utils)
```

```cpp
// consumer/main.cpp
#include "cpack_lib/core.h"
#include "cpack_lib/utils.h"
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
