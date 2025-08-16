# CPack Integration Tutorial

This tutorial demonstrates how `export_cpack()` attempts simplify CPack usage compared to manual configuration, while maintaining full flexibility and cross-platform compatibility.

## How CPack Works

**Important:** CPack only packages files that have explicit `install()` rules - it doesn't automatically include everything in your project.

### The Simple Rule
```cmake
# This gets packaged (has install rule)
add_library(mylib ...)
install(TARGETS mylib ...)  ✅ 

# This doesn't get packaged (no install rule)
add_executable(test_app ...)  ❌
```

### What Happens When You Run CPack

1. **Collect**: CPack gathers all files specified by `install()` commands
2. **Stage**: Copies them to a temporary staging directory
3. **Package**: Creates packages (`.deb`, `.rpm`, `.tar.gz`, etc.) from that staging directory

Package Generation: CPack can then create packages from the staging directory contents, e.g:

* TGZ/ZIP: Archives the entire staging directory
* DEB/RPM: Creates system packages with proper metadata
* WIX/NSIS: Builds Windows installers

**With `export_cpack()`**: The `target_install_package()` function automatically creates these install rules for you, but the same principle applies - only explicitly installed content gets packaged.

---

## Table of Contents

1. [Manual CPack: The Traditional Approach](#manual-cpack-the-traditional-approach)
2. [export_cpack(): The Simplified Approach](#export_cpack-the-simplified-approach)
3. [Side-by-Side Comparison](#side-by-side-comparison)
4. [Advanced Usage Examples](#advanced-usage-examples)
5. [GPG Package Signing](#gpg-package-signing)
6. [Cross-Platform Package Generation](#cross-platform-package-generation)
7. [Limitations and Trade-offs](#limitations-and-trade-offs)
8. [Migration Guide](#migration-guide)

---

## Manual CPack: The Traditional Approach

CPack configuration requires alot of effort for me, because I have to research how and why everytime I do it. Here's what you typically need to write:

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

## export_cpack(): The Simplified Approach

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
export_cpack(
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

| Aspect | Manual CPack | export_cpack() |
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
export_cpack(
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
export_cpack(
    PACKAGE_NAME "CustomPackage"
    GENERATORS "ZIP;DEB"  # Only these, ignore platform defaults
    NO_DEFAULT_GENERATORS  # Disable automatic generator detection
    COMPONENTS "Runtime;Tools"  # Subset of available components
)
```

### Example 3: Advanced Customization

```cmake
export_cpack(
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

### Example 4: Package with Full Signing

**In my opinion it should there should be a standard way to SECURELY consume packages in CMake, e.g via 'find_package()', 'fetchContent()' and other package managers like vcpkg, conan, xrepo etc, so that I can only use packages I have trusted keys for.** This is not that, but it is a step towards automating some of my pains. Also gpg can be used cross-platform and is already widely used for exactly this purpose. My vision is that we will eventually have OpenID (or similar) integration with dev keys, multi-party signing after reviews, so that true identity is hard to forge and someone can always be held accountable, while identities (like real name) can be protected until something bad goes down.

```cmake
# package with signing
export_cpack(
    PACKAGE_NAME "EnterpriseLibrary"
    PACKAGE_VENDOR "Enterprise Corp"
    PACKAGE_CONTACT "packaging@enterprise.com"
    PACKAGE_HOMEPAGE_URL "https://enterprise.com/library"
    
    # GPG signing configuration
    GPG_SIGNING_KEY "packaging@enterprise.com"
    GPG_PASSPHRASE_FILE "${CMAKE_SOURCE_DIR}/.gpg_passphrase"
    SIGNING_METHOD "both"  # Both detached and embedded signatures
    GENERATE_CHECKSUMS ON
    GPG_KEYSERVER "keys.enterprise.com"
    
    # Component-specific configuration
    COMPONENT_GROUPS ON
    DEFAULT_COMPONENTS "Runtime"
    
    # Custom packaging
    GENERATORS "TGZ;DEB;RPM;ZIP"
    ADDITIONAL_CPACK_VARS
        "CPACK_PACKAGE_RELOCATABLE" "OFF"
        "CPACK_DEBIAN_PACKAGE_SECTION" "libs"
        "CPACK_RPM_PACKAGE_GROUP" "Development/Libraries"
)
```

**Why GPG as the foundation:**
- Cross-platform compatibility
- Established cryptographic infrastructure
- Wide adoption in security-conscious communities
- Foundation for advanced features

### Example 5: Multi-Environment Signing Configuration

```cmake
# Conditional signing based on environment
if(DEFINED ENV{CI})
    # CI environment - ephemeral test keys
    set(SIGNING_KEY "ci-test@yourproject.local")
    set(SIGNING_METHOD "detached")
    set(KEYSERVER "")  # No keyserver for CI
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    # Production release - full security
    set(SIGNING_KEY "security@yourproject.com")
    set(SIGNING_METHOD "both")
    set(KEYSERVER "keyserver.ubuntu.com")
else()
    # Development - no signing
    set(SIGNING_KEY "")
endif()

export_cpack(
    PACKAGE_NAME "FlexiblePackage"
    PACKAGE_VENDOR "Your Company"
    
    # Conditional GPG configuration
    GPG_SIGNING_KEY "${SIGNING_KEY}"
    SIGNING_METHOD "${SIGNING_METHOD}"
    GPG_KEYSERVER "${KEYSERVER}"
    GENERATE_CHECKSUMS ON
)
```

---

## GPG Package Signing

`export_cpack()` includes comprehensive GPG signing capabilities to ensure package authenticity and integrity. This addresses CMake's lack of built-in package signing support.

### Why Package Signing Matters

**Security Benefits:**
- **Authenticity**: Verifies packages come from trusted sources
- **Integrity**: Detects tampering or corruption during transfer
- **Trust Chain**: Establishes cryptographic proof of origin
- **Compliance**: Meets enterprise security requirements

**Real-World Attack Prevention:**
- Supply chain attacks (compromised package repositories)
- Man-in-the-middle attacks during download
- Malicious package injection
- Accidental corruption

### Basic GPG Signing Example

```cmake
# GPG signing requires minimal configuration
export_cpack(
    PACKAGE_NAME "MySecureLib"
    PACKAGE_VENDOR "Acme Corp"
    PACKAGE_CONTACT "security@acme.com"
    
    # GPG signing configuration
    GPG_SIGNING_KEY "maintainer@acme.com"
    GENERATE_CHECKSUMS ON
)

include(CPack)
```

**Generated Output:**
```bash
# Packages with signatures and checksums
MySecureLib-1.0.0-Linux.tar.gz
MySecureLib-1.0.0-Linux.tar.gz.sig
MySecureLib-1.0.0-Linux.tar.gz.sha256
MySecureLib-1.0.0-Linux.tar.gz.sha512
```

### GPG Signing Parameters

#### GPG_SIGNING_KEY
**Purpose**: Identifies which GPG key to use for signing packages.

```cmake
# Email address (recommended - user-friendly)
GPG_SIGNING_KEY "maintainer@example.com"

# Or key ID (8-character hex)
GPG_SIGNING_KEY "A1B2C3D4"

# Environment variable fallback
GPG_SIGNING_KEY "$ENV{GPG_SIGNING_KEY}"
```

#### GPG_PASSPHRASE_FILE
**Purpose**: Provides secure passphrase input for automated signing.

```cmake
# Project-local passphrase file
GPG_PASSPHRASE_FILE "${CMAKE_SOURCE_DIR}/.gpg_passphrase"

# Absolute path for CI/CD
GPG_PASSPHRASE_FILE "/var/secrets/gpg_passphrase"

# Environment variable
GPG_PASSPHRASE_FILE "$ENV{GPG_PASSPHRASE_FILE}"
```

**Security Note**: File-based approach is more secure than environment variables as it:
- Avoids command-line visibility
- Isn't inherited by child processes  
- Supports proper file permissions

#### SIGNING_METHOD
**Purpose**: Controls how signatures are attached to packages.

```cmake
# Detached signatures (default - universal compatibility)
SIGNING_METHOD "detached"

# Embedded signatures (RPM native support)
SIGNING_METHOD "embedded"  

# Both methods (maximum compatibility)
SIGNING_METHOD "both"
```

#### GENERATE_CHECKSUMS
**Purpose**: Creates cryptographic checksums alongside signatures.

```cmake
GENERATE_CHECKSUMS ON  # Creates .sha256 and .sha512 files
```

**Benefits:**
- Faster verification than GPG (SHA256 vs RSA operations)
- Bandwidth-efficient update checking
- Defense in depth (signatures + checksums)
- Air-gapped environment support


#### GPG_KEYSERVER
**Purpose**: Specifies keyserver for public key distribution.

```cmake
# Ubuntu's reliable keyserver (default)
GPG_KEYSERVER "keyserver.ubuntu.com"

# Corporate keyserver
GPG_KEYSERVER "keys.corp.internal"

# Multiple keyservers for redundancy
GPG_KEYSERVER "keyserver.ubuntu.com;keys.corp.internal"
```

### Complete Signing Example

```cmake
cmake_minimum_required(VERSION 3.25)
project(SecureLibrary VERSION 2.1.0)

include(target_install_package.cmake)

# Create library targets
add_library(secure_core SHARED src/core.cpp)
target_sources(secure_core PUBLIC FILE_SET HEADERS 
    BASE_DIRS include FILES include/secure/core.h)

add_executable(secure_tool tools/secure_tool.cpp)
target_link_libraries(secure_tool PRIVATE secure_core)

# Install with automatic CMake config generation
target_install_package(secure_core 
    NAMESPACE Secure::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
)

target_install_package(secure_tool 
    NAMESPACE Secure::
    COMPONENT "Tools"
)

# Configure CPack with comprehensive signing
export_cpack(
    PACKAGE_NAME "SecureLibrary"
    PACKAGE_VENDOR "Security Corp"
    PACKAGE_CONTACT "security@securitycorp.com"
    PACKAGE_HOMEPAGE_URL "https://securitycorp.com/secure-library"
    
    # GPG signing configuration
    GPG_SIGNING_KEY "security@securitycorp.com"
    GPG_PASSPHRASE_FILE "${CMAKE_SOURCE_DIR}/.gpg_passphrase"
    SIGNING_METHOD "both"
    GENERATE_CHECKSUMS ON
    GPG_KEYSERVER "keyserver.ubuntu.com"
)

include(CPack)
```

### Consumer Verification Workflow

**Manual Verification:**
```bash
# Import public key
gpg --keyserver keyserver.ubuntu.com --recv-keys security@securitycorp.com

# Verify GPG signature
gpg --verify SecureLibrary-2.1.0-Linux.tar.gz.sig SecureLibrary-2.1.0-Linux.tar.gz

# Verify checksums
sha256sum -c SecureLibrary-2.1.0-Linux.tar.gz.sha256
sha512sum -c SecureLibrary-2.1.0-Linux.tar.gz.sha512
```

### CI/CD Integration

**GitHub Actions Example:**
```yaml
name: Secure Package Release

on:
  push:
    tags: ['v*']

jobs:
  secure-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Import GPG Key
        env:
          GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
          GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
        run: |
          echo "$GPG_PRIVATE_KEY" | gpg --batch --import
          echo "$GPG_PASSPHRASE" > .gpg_passphrase
          chmod 600 .gpg_passphrase
      
      - name: Build and Sign Packages
        env:
          GPG_SIGNING_KEY: ${{ secrets.GPG_SIGNING_KEY_ID }}
        run: |
          cmake -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build
          cd build && cpack --verbose
      
      - name: Verify Generated Signatures
        run: |
          cd build
          # Manual signature verification
          for package in *.tar.gz *.deb *.rpm; do
            if [[ -f "$package" && -f "$package.sig" ]]; then
              gpg --verify "$package.sig" "$package"
            fi
          done
      
      - name: Upload Signed Packages
        uses: actions/upload-artifact@v4
        with:
          name: signed-packages
          path: |
            build/*.tar.gz
            build/*.deb
            build/*.rpm
            build/*.sig
            build/*.sha256
            build/*.sha512
```

### Security Best Practices

#### Key Management
```bash
# Generate signing key for your project
gpg --full-generate-key
# Choose: RSA, 4096 bits, no expiration
# Use project email: security@yourproject.com

# Export public key for distribution
gpg --armor --export security@yourproject.com > project-public-key.asc

# Backup private key securely
gpg --armor --export-secret-keys security@yourproject.com > project-private-key.asc
# Store in secure location (password manager, HSM, etc.)
```

#### Production vs Test Keys
```cmake
# Test/CI configuration (ephemeral keys)
if(DEFINED ENV{CI})
    set(GPG_SIGNING_KEY "ci-test@yourproject.local")
    set(GPG_PASSPHRASE_FILE "/tmp/ci_passphrase")
else()
    # Production configuration
    set(GPG_SIGNING_KEY "security@yourproject.com")
    set(GPG_PASSPHRASE_FILE "${CMAKE_SOURCE_DIR}/.gpg_passphrase")
endif()

export_cpack(
    PACKAGE_NAME "YourProject"
    GPG_SIGNING_KEY "${GPG_SIGNING_KEY}"
    GPG_PASSPHRASE_FILE "${GPG_PASSPHRASE_FILE}"
    GENERATE_CHECKSUMS ON
)
```

#### File Permissions
```bash
# Secure passphrase file permissions
chmod 600 .gpg_passphrase  # Owner read/write only
chown $(whoami) .gpg_passphrase

# Add to .gitignore
echo ".gpg_passphrase" >> .gitignore
echo "*.asc" >> .gitignore  # Private key backups
```

### Enterprise Deployment

#### Corporate Keyserver Integration
```cmake
export_cpack(
    PACKAGE_NAME "CorporateLib"
    GPG_SIGNING_KEY "build-system@corp.internal"
    GPG_KEYSERVER "keys.corp.internal"
    
    # Corporate compliance requirements
    SIGNING_METHOD "both"
    GENERATE_CHECKSUMS ON
)
```

#### Air-Gapped Environments
```cmake
# Configuration for disconnected networks
export_cpack(
    PACKAGE_NAME "AirGappedLib"
    GPG_SIGNING_KEY "offline@secure.local"
    
    # No keyserver (manual key distribution)
    GPG_KEYSERVER ""
    
    # Checksum-only verification for faster validation
    GENERATE_CHECKSUMS ON
)
```

### Troubleshooting

#### Common Issues and Solutions

**"GPG key not found"**
```bash
# List available keys
gpg --list-secret-keys

# Import key if missing
gpg --import private-key.asc

# Use key ID instead of email
GPG_SIGNING_KEY "A1B2C3D4"
```

**"Permission denied on passphrase file"**
```bash
# Fix file permissions
chmod 600 .gpg_passphrase
chown $(whoami) .gpg_passphrase
```

**"Signature verification failed"**
```bash
# Check key trust
gpg --list-keys --with-colons | grep -A1 "sec:"

# Manually trust key for testing
gpg --edit-key security@yourproject.com trust quit
```

---

## Cross-Platform Package Generation

Our function automatically selects appropriate generators per platform:

### Linux
```cmake
export_cpack(PACKAGE_NAME "MyLib")
# Auto-generates: TGZ, DEB, RPM
# Output: MyLib-1.0.0-Linux.tar.gz, mylib_1.0.0_amd64.deb, mylib-1.0.0-1.x86_64.rpm
```

### Windows  
```cmake
export_cpack(PACKAGE_NAME "MyLib")
# Auto-generates: TGZ, ZIP, WIX (if available)
# Output: MyLib-1.0.0-Windows.tar.gz, MyLib-1.0.0-Windows.zip, MyLib-1.0.0-Windows.msi
```

### macOS
```cmake
export_cpack(PACKAGE_NAME "MyLib")
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

### Limitations of export_cpack()

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

### From Manual CPack to export_cpack()

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
   export_cpack(
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

`export_cpack()` provides a **modern, declarative approach** to CPack configuration that:

- **Reduces boilerplate** while maintaining full functionality
- **Prevents common errors** through smart defaults and auto-detection
- **Supports advanced use cases** through comprehensive override mechanisms
- **Works cross-platform** with appropriate generator selection

For most projects, `export_cpack()` provides the perfect balance of **simplicity and flexability**, allowing you to focus on building software rather than wrestling with packaging configuration.