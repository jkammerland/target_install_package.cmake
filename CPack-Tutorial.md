# CPack Integration Tutorial

This tutorial demonstrates how `target_configure_cpack()` dramatically simplifies CPack usage compared to manual configuration, while maintaining full flexibility and cross-platform compatibility.

## Table of Contents

1. [Manual CPack: The Traditional Approach](#manual-cpack-the-traditional-approach)
2. [target_configure_cpack(): The Simplified Approach](#target_configure_cpack-the-simplified-approach)
3. [Side-by-Side Comparison](#side-by-side-comparison)
4. [Advanced Usage Examples](#advanced-usage-examples)
5. [Cross-Platform Package Generation](#cross-platform-package-generation)
6. [Limitations and Trade-offs](#limitations-and-trade-offs)
7. [Migration Guide](#migration-guide)

---

## Manual CPack: The Traditional Approach

Traditional CPack configuration requires extensive manual setup. Here's what you typically need to write:

### Step 1: Basic Project Setup (Manual)

```cmake
cmake_minimum_required(VERSION 3.25)
project(MyProject VERSION 1.2.0)

# Create targets
add_library(mylib SHARED src/mylib.cpp)
target_sources(mylib PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/mylib/core.h)

add_library(mylib_utils STATIC src/utils.cpp)  
target_sources(mylib_utils PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/mylib/utils.h)

add_executable(mytool src/tool.cpp)
target_link_libraries(mytool PRIVATE mylib)
```

### Step 2: Manual Installation Rules

```cmake
include(GNUInstallDirs)

# Install shared library (Runtime component)
install(TARGETS mylib
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}  # Windows DLLs
    COMPONENT Runtime
)

# Install static library (Development component)
install(TARGETS mylib_utils
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    COMPONENT Development
)

# Install executable (Tools component)
install(TARGETS mytool
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT Tools
)

# Install headers manually
install(DIRECTORY include/ 
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT Development
)

# Create and install CMake config files manually
include(CMakePackageConfigHelpers)
configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/mylib-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/mylib-config.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/mylib
)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/mylib-config-version.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/mylib-config.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/mylib-config-version.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/mylib
    COMPONENT Development
)
```

### Step 3: Manual CPack Configuration

```cmake
# Set basic package metadata
set(CPACK_PACKAGE_NAME "MyProject")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${PROJECT_VERSION_PATCH}")
set(CPACK_PACKAGE_VENDOR "Acme Corp")
set(CPACK_PACKAGE_CONTACT "support@acme.com")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "My awesome library package")

# Auto-detect license file
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
endif()

# Define all components
set(CPACK_COMPONENTS_ALL Runtime Development Tools)

# Set platform-specific generators
if(WIN32)
    set(CPACK_GENERATOR "TGZ;ZIP")
    find_program(WIX_CANDLE_EXECUTABLE candle)
    if(WIX_CANDLE_EXECUTABLE)
        list(APPEND CPACK_GENERATOR "WIX")
        set(CPACK_WIX_COMPONENT_INSTALL ON)
        # Generate unique GUID for upgrades
        string(UUID CPACK_WIX_UPGRADE_GUID NAMESPACE "6BA7B810-9DAD-11D1-80B4-00C04FD430C8" 
               NAME "${CPACK_PACKAGE_NAME}" TYPE SHA1)
        set(CPACK_WIX_UNINSTALL ON)
    endif()
elseif(UNIX AND NOT APPLE)
    set(CPACK_GENERATOR "TGZ;DEB;RPM")
    # Enable component installation for Linux packages
    set(CPACK_DEB_COMPONENT_INSTALL ON)
    set(CPACK_RPM_COMPONENT_INSTALL ON)
    # Set Debian-specific settings
    set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    # Set RPM-specific settings
    set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
    set(CPACK_RPM_PACKAGE_LICENSE "Unknown")
elseif(APPLE)
    set(CPACK_GENERATOR "TGZ;DragNDrop")
endif()

# Enable component installation for multi-component packages
set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)

# Set component descriptions
set(CPACK_COMPONENT_RUNTIME_DESCRIPTION "Runtime libraries and executables")
set(CPACK_COMPONENT_RUNTIME_DISPLAY_NAME "Runtime Files")

set(CPACK_COMPONENT_DEVELOPMENT_DESCRIPTION "Headers, static libraries, and development files")
set(CPACK_COMPONENT_DEVELOPMENT_DISPLAY_NAME "Development Files")
set(CPACK_COMPONENT_DEVELOPMENT_DEPENDS Runtime)

set(CPACK_COMPONENT_TOOLS_DESCRIPTION "Command-line tools and utilities")
set(CPACK_COMPONENT_TOOLS_DISPLAY_NAME "Tools")

# Set default components
set(CPACK_COMPONENTS_DEFAULT Runtime)

include(CPack)
```

**Total Lines of CMake Code: ~85 lines** just for packaging setup!

---

## target_configure_cpack(): The Simplified Approach

Now, let's see the same functionality using our simplified approach:

### Complete Example

```cmake
cmake_minimum_required(VERSION 3.25)
project(MyProject VERSION 1.2.0 DESCRIPTION "My awesome library package")

# Include target_install_package utilities
include(target_install_package.cmake)  # or use FetchContent

# Create targets (same as before)
add_library(mylib SHARED src/mylib.cpp)
target_sources(mylib PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/mylib/core.h)

add_library(mylib_utils STATIC src/utils.cpp)
target_sources(mylib_utils PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/mylib/utils.h)

add_executable(mytool src/tool.cpp)
target_link_libraries(mytool PRIVATE mylib)

# Install with automatic component detection and CMake config generation
target_install_package(mylib NAMESPACE MyLib:: RUNTIME_COMPONENT "Runtime" DEVELOPMENT_COMPONENT "Development")
target_install_package(mylib_utils NAMESPACE MyLib:: DEVELOPMENT_COMPONENT "Development")
target_install_package(mytool NAMESPACE MyLib:: COMPONENT "Tools")

# Configure CPack with smart defaults and auto-detection
target_configure_cpack(
    PACKAGE_NAME "MyProject"
    PACKAGE_VENDOR "Acme Corp"
    PACKAGE_CONTACT "support@acme.com"
    # Everything else is auto-detected:
    # - Components: Runtime, Development, Tools
    # - Generators: Platform-specific (TGZ/ZIP/DEB/RPM/WIX/DragNDrop)
    # - Version: From PROJECT_VERSION
    # - License: Auto-detected (LICENSE, LICENSE.txt, etc.)
    # - Component relationships and descriptions
)

include(CPack)
```

**Total Lines of CMake Code: ~20 lines** - a **75% reduction**!

---

## Side-by-Side Comparison

| Aspect | Manual CPack | target_configure_cpack() |
|--------|-------------|---------------------------|
| **Lines of Code** | ~85 lines | ~20 lines |
| **Installation Rules** | Manual `install()` commands | Automatic via `target_install_package()` |
| **CMake Config Files** | Manual generation | Automatic generation |
| **Component Detection** | Manual listing | Auto-detected from install calls |
| **Platform Detection** | Manual conditional logic | Automatic platform-appropriate generators |
| **License Detection** | Manual file checking | Automatic discovery |
| **Component Descriptions** | Manual setup | Smart defaults with override capability |
| **Version Handling** | Manual variable parsing | Automatic from PROJECT_VERSION |
| **Error Prone** | High (easy to miss steps) | Low (smart defaults) |
| **Maintainability** | Low (lots of boilerplate) | High (declarative) |

---

## Advanced Usage Examples

### Example 1: Multi-Target Package with Dependencies

```cmake
# Traditional approach would require ~150+ lines
# Our approach:

find_package(OpenGL REQUIRED)
find_package(glfw3 REQUIRED)

add_library(graphics_engine SHARED src/graphics.cpp)
target_sources(graphics_engine PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/graphics/engine.h)
target_link_libraries(graphics_engine PUBLIC OpenGL::GL glfw)

add_library(audio_engine STATIC src/audio.cpp)  
target_sources(audio_engine PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/audio/engine.h)

add_executable(game_editor tools/editor.cpp)
target_link_libraries(game_editor PRIVATE graphics_engine audio_engine)

# Install with dependencies automatically handled
target_install_package(graphics_engine 
    NAMESPACE GameEngine::
    PUBLIC_DEPENDENCIES "OpenGL REQUIRED" "glfw3 3.3 REQUIRED"
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "SDK"
)

target_install_package(audio_engine 
    NAMESPACE GameEngine::
    DEVELOPMENT_COMPONENT "SDK"
)

target_install_package(game_editor 
    NAMESPACE GameEngine::
    COMPONENT "Tools"
)

# One call configures everything
target_configure_cpack(
    PACKAGE_NAME "GameEngine"
    PACKAGE_VENDOR "Game Studio"
    DEFAULT_COMPONENTS "Runtime"
    COMPONENT_GROUPS  # Enables group-based UI
)

include(CPack)
```

### Example 2: Custom Generator Selection

```cmake
# Force specific generators and disable auto-detection
target_configure_cpack(
    PACKAGE_NAME "CustomPackage"
    GENERATORS "ZIP;DEB"  # Only these, ignore platform defaults
    NO_DEFAULT_GENERATORS  # Disable automatic generator detection
    COMPONENTS "Runtime;Tools"  # Subset of available components
)
```

### Example 3: Advanced Customization

```cmake
target_configure_cpack(
    PACKAGE_NAME "AdvancedLib"
    PACKAGE_VERSION "2.0.0-beta"  # Override project version
    PACKAGE_VENDOR "Tech Corp"
    PACKAGE_HOMEPAGE_URL "https://techcorp.com/advancedlib"
    LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/custom-license.txt"
    ADDITIONAL_CPACK_VARS
        "CPACK_PACKAGE_EXECUTABLES" "mytool;MyTool"
        "CPACK_CREATE_DESKTOP_LINKS" "mytool"
)
```

---

## Cross-Platform Package Generation

Our function automatically selects appropriate generators per platform:

### Linux
```cmake
target_configure_cpack(PACKAGE_NAME "MyLib")
# Auto-generates: TGZ, DEB, RPM
# Output: MyLib-1.0.0-Linux.tar.gz, mylib_1.0.0_amd64.deb, mylib-1.0.0-1.x86_64.rpm
```

### Windows  
```cmake
target_configure_cpack(PACKAGE_NAME "MyLib")
# Auto-generates: TGZ, ZIP, WIX (if available)
# Output: MyLib-1.0.0-Windows.tar.gz, MyLib-1.0.0-Windows.zip, MyLib-1.0.0-Windows.msi
```

### macOS
```cmake
target_configure_cpack(PACKAGE_NAME "MyLib")
# Auto-generates: TGZ, DragNDrop
# Output: MyLib-1.0.0-Darwin.tar.gz, MyLib-1.0.0-Darwin.dmg
```

### Component-Based Packages

When multiple components are detected, packages are automatically split:

```bash
# Linux output with components
MyLib-1.0.0-Linux-Runtime.tar.gz      # Shared libraries
MyLib-1.0.0-Linux-Development.tar.gz  # Headers + CMake configs + static libs
MyLib-1.0.0-Linux-Tools.tar.gz        # Executables

# Corresponding DEB packages
mylib-runtime_1.0.0_amd64.deb
mylib-development_1.0.0_amd64.deb  
mylib-tools_1.0.0_amd64.deb
```

---

## Limitations and Trade-offs

### Limitations of target_configure_cpack()

1. **Opinionated Defaults**: Uses conventional component names (Runtime, Development, Tools)
   - **Workaround**: Override with custom component names in `target_install_package()`

2. **Auto-Detection Dependency**: Relies on prior `target_install_package()` calls
   - **Workaround**: Can specify `COMPONENTS` explicitly to override detection

3. **Limited Template Customization**: Uses built-in component descriptions
   - **Workaround**: Use `ADDITIONAL_CPACK_VARS` for fine-grained control

4. **Generator Selection**: Auto-detection might not match specific requirements
   - **Workaround**: Use `GENERATORS` and `NO_DEFAULT_GENERATORS` for explicit control

### When to Use Manual CPack

Consider manual CPack configuration when you need:

- **Highly Custom Component Structure**: Non-standard component hierarchies
- **Specialized Generator Settings**: WiX customization, custom DEB control files
- **Legacy Integration**: Existing complex packaging scripts
- **Platform-Specific Packages**: Dramatically different packaging per platform

---

## Migration Guide

### From Manual CPack to target_configure_cpack()

1. **Replace Installation Rules**:
   ```cmake
   # Before
   install(TARGETS mylib LIBRARY DESTINATION lib COMPONENT Runtime)
   install(FILES mylib.h DESTINATION include COMPONENT Development)
   
   # After  
   target_install_package(mylib RUNTIME_COMPONENT "Runtime" DEVELOPMENT_COMPONENT "Development")
   ```

2. **Replace CPack Variables**:
   ```cmake
   # Before
   set(CPACK_PACKAGE_NAME "MyLib")
   set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
   set(CPACK_COMPONENTS_ALL Runtime Development)
   # ... 50+ lines of configuration ...
   
   # After
   target_configure_cpack(
       PACKAGE_NAME "MyLib"
       # Auto-detects version, components, generators
   )
   ```

3. **Handle Dependencies**:
   ```cmake
   # Before
   find_package(fmt REQUIRED)
   target_link_libraries(mylib PUBLIC fmt::fmt)
   # Manual CMake config file generation...
   
   # After
   find_package(fmt REQUIRED)
   target_link_libraries(mylib PUBLIC fmt::fmt)
   target_install_package(mylib 
       PUBLIC_DEPENDENCIES "fmt 9.0 REQUIRED"
       # Automatic CMake config generation with dependencies
   )
   ```
---

## Conclusion

`target_configure_cpack()` provides a **modern, declarative approach** to CPack configuration that:

- **Reduces boilerplate** while maintaining full functionality
- **Prevents common errors** through smart defaults and auto-detection
- **Supports advanced use cases** through comprehensive override mechanisms
- **Works cross-platform** with appropriate generator selection

For most projects, `target_configure_cpack()` provides the perfect balance of **simplicity and flexability**, allowing you to focus on building software rather than wrestling with packaging configuration.