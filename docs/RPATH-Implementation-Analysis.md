# RPATH Implementation Analysis

## Overview

This document captures the research, design, and implementation insights from adding RPATH support to `target_install_package`. While the initial implementation worked, it needs to be redesigned for better integration and robustness.

## Problem Statement

Users need to install binaries with shared libraries in non-system locations (like `/opt/myapp` or custom prefixes) and have them work without requiring:
- Modifying system-wide `LD_LIBRARY_PATH` 
- Installing libraries to system directories
- Manual path configuration by end users

## Research Findings

### CMake RPATH Mechanisms

1. **Key Variables:**
   - `CMAKE_INSTALL_RPATH`: Global RPATH for all installed targets
   - `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Automatically add linked library directories
   - `CMAKE_SKIP_RPATH`: Disable RPATH completely
   - `CMAKE_BUILD_WITH_INSTALL_RPATH`: Use install RPATH during build

2. **Key Properties (per-target):**
   - `INSTALL_RPATH`: Target-specific RPATH entries
   - `BUILD_RPATH`: RPATH for build-tree binaries
   - `BUILD_WITH_INSTALL_RPATH`: Use install RPATH during build
   - `INSTALL_RPATH_USE_LINK_PATH`: Per-target version of global setting

3. **Platform Differences:**
   - **Linux**: `$ORIGIN/path` - relative to binary location
   - **macOS**: `@executable_path/path` (executables), `@loader_path/path` (libraries)
   - **Windows**: No RPATH support - uses different DLL discovery mechanisms

### Best Practices from CMake Documentation

```cmake
# Common pattern for relocatable installations
if(APPLE)
  set(CMAKE_INSTALL_RPATH "@executable_path/../lib")
elseif(UNIX)
  set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")
endif()

# Enable automatic RPATH management
if(UNIX)
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
  set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
endif()
```

## Current State Analysis

### Existing Behavior
- The project documentation mentions "CMake automatically sets RPATH/RUNPATH" but no explicit RPATH handling exists
- Installation uses standard `install(TARGETS)` without RPATH configuration
- Works for system installations but fails for custom prefixes

### Installation Structure
Current installation layout assumes standard structure:
```
prefix/
├── bin/           # Executables
├── lib/           # Libraries  
├── include/       # Headers
└── share/cmake/   # Config files
```

## Implementation Design

### Architecture Decisions

1. **Hybrid Approach**: Provide sensible defaults with customization options
2. **Integration Point**: Add RPATH logic before `install(${INSTALL_ARGS})` call
3. **Backward Compatibility**: Make all features optional and non-breaking

### API Design

Added parameters to `target_install_package()`:

```cmake
target_install_package(my_target
  # ... existing parameters ...
  
  # RPATH parameters
  INSTALL_RPATH <path1;path2;...>    # Custom RPATH entries
  DISABLE_RPATH                       # Disable automatic RPATH
  RPATH_USE_LINK_PATH                # Add linked library dirs to RPATH
)
```

### Implementation Logic

```cmake
# Configure RPATH for Linux/macOS if not disabled
if(NOT ARG_DISABLE_RPATH AND NOT WIN32)
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
  if(TARGET_TYPE STREQUAL "EXECUTABLE" OR TARGET_TYPE STREQUAL "SHARED_LIBRARY")
    # Check existing RPATH to avoid overriding user settings
    get_target_property(EXISTING_RPATH ${TARGET_NAME} INSTALL_RPATH)
    
    set(RPATH_ENTRIES)
    
    # Add custom entries if specified
    if(ARG_INSTALL_RPATH)
      list(APPEND RPATH_ENTRIES ${ARG_INSTALL_RPATH})
    endif()
    
    # Add platform-appropriate defaults if no existing/custom RPATH
    if(NOT EXISTING_RPATH AND NOT ARG_INSTALL_RPATH)
      if(APPLE)
        if(TARGET_TYPE STREQUAL "EXECUTABLE")
          list(APPEND RPATH_ENTRIES "@executable_path/../lib")
        else()
          list(APPEND RPATH_ENTRIES "@loader_path/../lib")
        endif()
      elseif(UNIX)
        list(APPEND RPATH_ENTRIES "$ORIGIN/../lib")
      endif()
    endif()
    
    # Apply RPATH settings
    if(RPATH_ENTRIES)
      set_target_properties(${TARGET_NAME} PROPERTIES INSTALL_RPATH "${RPATH_ENTRIES}")
    endif()
    
    if(ARG_RPATH_USE_LINK_PATH)
      set_target_properties(${TARGET_NAME} PROPERTIES INSTALL_RPATH_USE_LINK_PATH ON)
    endif()
  endif()
endif()
```

## Testing Results

### Successful Tests

1. **Basic Shared Library** (`string_utils`):
   ```
   Debug: Set INSTALL_RPATH for 'string_utils': $ORIGIN/../lib
   Install: Set non-toolchain portion of runtime path ... to "$ORIGIN/../lib"
   Binary: RUNPATH: [$ORIGIN/../lib] ✓
   ```

2. **Multi-target Example** (components-same-export):
   - Shared libraries: `$ORIGIN/../lib` ✓
   - Executables: `$ORIGIN/../lib` ✓
   - All targets configured correctly ✓

3. **Backward Compatibility**:
   - Existing examples continue to work
   - No breaking changes to API
   - Optional parameters work as expected

### Verification Commands

```bash
# Build and install
cmake -B build -G Ninja --log-level=DEBUG
cmake --build build
cmake --install build

# Verify RPATH in binary
readelf -d path/to/library.so | grep -E "(RPATH|RUNPATH)"
# Expected: RUNPATH: [$ORIGIN/../lib]
```

## Implementation Issues Discovered

### 1. Custom RPATH Parameter Parsing
- Issue: Custom RPATH entries weren't being applied correctly
- Root Cause: Argument parsing or variable scope issues
- Evidence: Debug output showed default RPATH instead of custom values

### 2. DISABLE_RPATH Logic
- Issue: DISABLE_RPATH flag didn't prevent RPATH from being set
- Root Cause: Logic condition needs refinement
- Impact: Cannot fully disable automatic behavior when needed

### 3. Integration Location
- Current: Added before `install(${INSTALL_ARGS})` call
- Issue: May need to be applied earlier in target preparation
- Consideration: Some properties must be set before installation rules

## Usage Examples

### Basic Automatic RPATH
```cmake
# Gets platform-appropriate default RPATH
target_install_package(my_library)
```

### Custom RPATH Configuration
```cmake
# For non-standard installation layouts
target_install_package(my_executable
  INSTALL_RPATH "/opt/myapp/lib;/usr/local/custom/lib")
```

### System-wide Installation
```cmake
# Disable RPATH for system libraries
target_install_package(system_library
  DISABLE_RPATH)
```

### Development Configuration
```cmake
# Include linked library directories in RPATH
target_install_package(my_app
  RPATH_USE_LINK_PATH)
```

## Recommended Redesign Approach

### 1. Global Configuration First
Set project-wide RPATH policies before target-specific configuration:

```cmake
# In target_prepare_package or separate function
if(NOT WIN32 AND NOT CMAKE_INSTALL_RPATH)
  if(APPLE)
    set(CMAKE_INSTALL_RPATH "@executable_path/../lib" PARENT_SCOPE)
  elseif(UNIX)
    set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib" PARENT_SCOPE)
  endif()
endif()
```

### 2. Target-specific Override
Allow per-target customization while respecting global defaults:

```cmake
# Only override if explicitly requested
if(ARG_INSTALL_RPATH)
  set_target_properties(${TARGET_NAME} PROPERTIES INSTALL_RPATH "${ARG_INSTALL_RPATH}")
endif()
```

### 3. Early Configuration
Apply RPATH settings during target preparation phase, not installation phase.

### 4. Better Integration
Consider adding RPATH configuration as a separate function that can be called independently.

## Files Modified

1. **target_install_package.cmake**:
   - Added RPATH parameters to API documentation
   - Added usage examples
   - Updated behavior description

2. **install_package_helpers.cmake**:
   - Added RPATH parameters to argument parsing
   - Added RPATH configuration logic before installation
   - Added debug logging for RPATH settings

## Testing Strategy for Redesign

1. **Unit Tests**: Test each RPATH scenario independently
2. **Integration Tests**: Verify with existing examples
3. **Platform Tests**: Ensure Linux/macOS/Windows compatibility  
4. **Edge Cases**: Empty RPATH, existing RPATH, interface libraries
5. **Real-world Usage**: Test with actual consumer applications

## Conclusion

The RPATH implementation successfully addresses the core requirement of enabling non-system installations. The basic functionality works correctly, but the parameter handling and integration points need refinement for a production-ready solution.

Key insights:
- Platform-specific RPATH defaults work well (`$ORIGIN/../lib` for Linux, `@executable_path/../lib` for macOS)
- Integration before `install()` call is the right approach
- Respecting existing RPATH properties is crucial for compatibility
- Debug logging is essential for troubleshooting RPATH issues

The redesign should focus on robust parameter handling, cleaner integration, and comprehensive testing while preserving the core working functionality.