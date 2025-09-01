# export_cpack User Customization Guide

This document explains how users can customize and extend the `export_cpack` function to meet specific packaging requirements.

## Understanding export_cpack

The `export_cpack` function automatically configures CPack based on your `target_install_package` components. It follows a **logical component pattern** that simplifies package organization:

- **Traditional CPack**: Components like `Runtime`, `Development`, `Documentation`
- **Logical Components**: Groups like `Core_Runtime`, `Core_Development`, `Tools_Runtime`, `Utils_Development`

## Key Features Verified

### ✅ Package Format Support
- **TGZ packages**: Work correctly with all component types
- **RPM packages**: Properly handle RPATH and system paths
- **Mixed scenarios**: Traditional and logical components coexist

### ✅ Component Organization  
- **Runtime-only components**: Executables and shared libraries
- **Development-only components**: Headers and interface libraries
- **Mixed components**: Both runtime and development parts
- **Cross-component dependencies**: Handled via CMake target linking

### ✅ Packaging Scenarios Tested
1. Complex dependency chains (Foundation → Core → Extensions → Utils → Applications)
2. Unusual component names (underscores, numbers, long names)
3. Empty component groups (components with no Runtime or Development parts)
4. Cross-component dependencies (UI depends on Network + Graphics)

## Basic Usage

```cmake
export_cpack(
  PACKAGE_NAME "MyProject"
  PACKAGE_DESCRIPTION "My awesome project"
  PACKAGE_VENDOR "My Company"
  PACKAGE_CONTACT "support@mycompany.com"
  GENERATORS "TGZ;RPM"
)
```

## Customization Points

### 1. Package Metadata Customization

```cmake
export_cpack(
  PACKAGE_NAME "CustomPackageName"           # Override auto-detected name
  PACKAGE_DESCRIPTION "Detailed description"
  PACKAGE_VENDOR "Your Organization"
  PACKAGE_CONTACT "you@domain.com"
  
  # Additional metadata (passed directly to CPack)
  VERSION "1.2.3"                           # Override project version
  HOMEPAGE_URL "https://myproject.org"
  LICENSE "MIT"
)
```

### 2. Generator Selection

```cmake
export_cpack(
  PACKAGE_NAME "MyProject"
  GENERATORS "TGZ;RPM;DEB"                  # Multiple generators
)

# Platform-specific generators
if(WIN32)
  set(MY_GENERATORS "ZIP;NSIS")
elseif(APPLE)
  set(MY_GENERATORS "TGZ;DragNDrop")
else()
  set(MY_GENERATORS "TGZ;RPM;DEB")
endif()

export_cpack(
  PACKAGE_NAME "MyProject"
  GENERATORS "${MY_GENERATORS}"
)
```

### 3. Component Group Control

The function automatically detects logical component groups from naming patterns:

```cmake
# These create logical groups automatically:
target_install_package(core_lib COMPONENT Core)      # → Core group
target_install_package(net_lib COMPONENT Network)    # → Network group  
target_install_package(app COMPONENT Tools)          # → Tools group

# Results in packages:
# - MyProject-Core.tar.gz (contains Core_Runtime + Core_Development)
# - MyProject-Network.tar.gz 
# - MyProject-Tools.tar.gz
```

### 4. Advanced CPack Variable Override

You can set CPack variables before calling `export_cpack` to override defaults:

```cmake
# Override component descriptions
set(CPACK_COMPONENT_CORE_RUNTIME_DESCRIPTION "Core runtime libraries")
set(CPACK_COMPONENT_CORE_DEVELOPMENT_DESCRIPTION "Core development headers")

# Configure component dependencies  
set(CPACK_COMPONENT_NETWORK_RUNTIME_DEPENDS Core_Runtime)

# Set package-specific variables
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_DEB_COMPONENT_INSTALL ON)

export_cpack(PACKAGE_NAME "MyProject" GENERATORS "RPM;DEB")
```

### 5. GPG Signing Configuration

```cmake
export_cpack(
  PACKAGE_NAME "MyProject"
  GENERATORS "TGZ;RPM"
  GPG_KEY_ID "your-key-id"                  # Enable GPG signing
  GPG_KEY_FILE "/path/to/private.key"       # Optional: specify key file
)
```

### 6. Installation Prefix Handling

The function handles different installation scenarios:

```cmake
# For system packages (avoid RPATH issues)
cmake -DCMAKE_INSTALL_PREFIX=/usr

# For user packages (with RPATH)  
cmake -DCMAKE_INSTALL_PREFIX=/opt/myproject

export_cpack(PACKAGE_NAME "MyProject" GENERATORS "RPM")
```

**Important**: When targeting system paths (`/usr`), RPATH is automatically disabled to comply with RPM packaging standards.

## Integration Patterns

### Pattern 1: Simple Single Package

```cmake
target_install_package(mylib EXPORT_NAME MyProject COMPONENT Runtime)
target_install_package(myapp EXPORT_NAME MyProject COMPONENT Runtime) 

export_cpack(
  PACKAGE_NAME "MyProject"
  GENERATORS "TGZ"
)
# Result: Single MyProject-Runtime.tar.gz package
```

### Pattern 2: Multi-Component Architecture

```cmake
target_install_package(core_lib EXPORT_NAME MyProject COMPONENT Core)
target_install_package(plugin_lib EXPORT_NAME MyProject COMPONENT Plugins)  
target_install_package(tools_app EXPORT_NAME MyProject COMPONENT Tools)

export_cpack(
  PACKAGE_NAME "MyProject" 
  GENERATORS "TGZ;RPM"
)
# Result: 3 packages per generator (Core, Plugins, Tools)
```

### Pattern 3: Mixed Traditional/Logical Components

```cmake
# Traditional components (no prefix pattern)
install(FILES README.txt DESTINATION . COMPONENT Documentation)

# Logical components (prefix pattern)  
target_install_package(mylib EXPORT_NAME MyProject COMPONENT Core)

export_cpack(PACKAGE_NAME "MyProject" GENERATORS "TGZ")
# Result: MyProject-Core.tar.gz + single Documentation files
```

## Troubleshooting

### RPATH Issues with RPM

**Problem**: RPM build fails with "invalid runpath" errors
**Solution**: Use system prefix or disable RPATH:

```cmake
# Option 1: Use system prefix
cmake -DCMAKE_INSTALL_PREFIX=/usr

# Option 2: Conditional RPATH (recommended pattern)
if(NOT CMAKE_INSTALL_PREFIX STREQUAL "/usr")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
endif()
```

### Component Not Found

**Problem**: Components not appearing in packages
**Solution**: Verify component naming and target installation:

```cmake
# Check component names match the pattern
target_install_package(mylib COMPONENT MyComponent)  # → MyComponent_Runtime/Development

# Verify installation actually happens  
cmake --install build --component MyComponent_Runtime
```

### Empty Packages

**Problem**: Packages created but contain no files
**Solution**: Check file installation and component assignment:

```cmake
# Interface libraries only create Development components
add_library(headers INTERFACE)
target_install_package(headers COMPONENT Headers)  # → Headers_Development only

# Executables only create Runtime components  
target_install_package(app COMPONENT Apps)         # → Apps_Runtime only
```

## Best Practices

1. **Use descriptive component names**: `Core`, `Network`, `Tools` instead of generic names
2. **Group related functionality**: Put related libraries in the same component  
3. **Test package contents**: Use `tar -tf` and `rpm -qlp` to verify contents
4. **Handle RPATH correctly**: Use conditional RPATH for cross-platform support
5. **Document component dependencies**: Clear relationships help users understand packages

## Advanced Example

```cmake
cmake_minimum_required(VERSION 3.25)
project(MyProject VERSION 2.1.0)

include(target_install_package.cmake)

# Configure RPATH conditionally  
if(NOT CMAKE_INSTALL_PREFIX STREQUAL "/usr")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib64")
endif()

# Create libraries with logical grouping
target_install_package(core_lib EXPORT_NAME MyProject COMPONENT Core)
target_install_package(network_lib EXPORT_NAME MyProject COMPONENT Network)  
target_install_package(ui_app EXPORT_NAME MyProject COMPONENT Applications)

# Traditional documentation component
install(FILES README.txt LICENSE DESTINATION share/doc/myproject 
        COMPONENT Documentation)

# Override specific component descriptions
set(CPACK_COMPONENT_CORE_DEVELOPMENT_DESCRIPTION "Core development headers and CMake config")
set(CPACK_COMPONENT_APPLICATIONS_RUNTIME_DESCRIPTION "End-user applications")

# Configure comprehensive packaging
export_cpack(
  PACKAGE_NAME "MyProject"
  PACKAGE_DESCRIPTION "A comprehensive project with multiple components"
  PACKAGE_VENDOR "My Organization" 
  PACKAGE_CONTACT "support@myorg.com"
  GENERATORS "TGZ;RPM;DEB"
  HOMEPAGE_URL "https://myproject.org"
)

# Result: 4 packages per generator:
# - MyProject-Core (libraries + headers)
# - MyProject-Network (network libraries + headers)  
# - MyProject-Applications (UI applications)
# - Traditional Documentation component (merged appropriately)
```

This creates a robust, user-friendly packaging setup that handles complex scenarios while remaining simple for basic use cases.