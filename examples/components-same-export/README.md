# Multi-Target Export with Component Separation

This example demonstrates the **correct pattern** for packaging multiple targets into a single export with different component assignments and aggregated dependencies.

## Key Features Demonstrated

- **Multi-Target Export**: 4 targets packaged into 1 export (`engine2`)
- **Dependency Aggregation**: Multiple `PUBLIC_DEPENDENCIES` combined into single config file
- **Component Separation**: Different targets assigned to different components
- **Correct API Usage**: `target_prepare_package()` + `finalize_package()` pattern

## Architecture

```
engine2 Package:
   media_core2 (shared)     � runtime1 + devel1 components
   media_dev_tools2 (static)� devel2 component  
   storage (shared)         � devel3 component
   asset_converter2 (exe)   � tools component
```

## Under the Hood

This example uses the **two-phase approach**:

1. **Preparation Phase**: Each `target_prepare_package()` call stores target configuration in global properties
2. **Finalization Phase**: Single `finalize_package()` call aggregates all configurations and generates unified export files

**Global Property Storage Pattern:**
```cmake
# Per-target component assignments
TIP_EXPORT_engine2_TARGET_media_core2_RUNTIME_COMPONENT = "runtime1"
TIP_EXPORT_engine2_TARGET_media_core2_DEVELOPMENT_COMPONENT = "devel1"
TIP_EXPORT_engine2_TARGET_media_dev_tools2_DEVELOPMENT_COMPONENT = "devel2"
# ... etc for all targets

# Aggregated data
TIP_EXPORT_engine2_TARGETS = "media_core2;media_dev_tools2;storage;asset_converter2"
TIP_EXPORT_engine2_PUBLIC_DEPENDENCIES = "aggregated list"
```

## Building and Installing

### Step 1: Configure and Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
cmake --build .
```

**Expected Configuration Output:**
```
-- [target_install_package][STATUS] 'media_core2' configured successfully for export 'engine2' (runtime: runtime1, dev: devel1)
-- [target_install_package][STATUS] 'media_dev_tools2' configured successfully for export 'engine2' (runtime: Runtime, dev: devel2)
-- [target_install_package][STATUS] 'storage' configured successfully for export 'engine2' (runtime: Runtime, dev: devel3)
-- [target_install_package][STATUS] 'asset_converter2' configured successfully for export 'engine2' (runtime: tools, dev: Development)
-- [target_install_package][STATUS] Export 'engine2' finalizing 4 targets: [media_core2;media_dev_tools2;storage;asset_converter2]
-- [target_install_package][STATUS] Components in export 'engine2':
-- [target_install_package][STATUS]   Runtime: runtime1 Runtime tools
-- [target_install_package][STATUS]   Development: devel1 devel2 devel3 Development
-- [target_install_package][STATUS]   Other: tools
```

### Step 2: Install Components

```bash
# Install everything
cmake --install .

# Or install specific components
cmake --install . --component runtime1  # Core runtime library only
cmake --install . --component devel1    # Core development files
cmake --install . --component tools     # Asset converter tool
```

### Step 3: Verify Single Export Generated

**Installation structure:**
```
install/
   bin/
      asset_converter2         # tools component
   include/
      media/
         core.h              # devel1 component  
         dev_tools.h         # devel2 component
      storage/
          storage.h           # devel3 component
   lib64/
      libmedia_core2.so*      # runtime1 component
      libmedia_dev_tools2.a   # devel2 component
      libstorage.so*          # devel3 component
   share/cmake/engine2/         # Single export for all targets
       engine2-config.cmake
       engine2-config-version.cmake
       engine2.cmake
```

**Key Point**: Only **one** export directory (`engine2/`) is generated, not separate exports for each target.

## Generated Config File Analysis

The generated `engine2-config.cmake` contains all targets:

```cmake
# Include the targets file
include("${CMAKE_CURRENT_LIST_DIR}/engine2.cmake")

check_required_components(engine2)
```

The `engine2.cmake` file includes all 4 targets:
```cmake
# Generated CMake target import file
foreach(_cmake_expected_target IN ITEMS Media::media_core2 Media::media_dev_tools2 Media::storage Media::asset_converter2)
  # ... target import logic
```

## Using the Installed Package

### Consumer CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.25)
project(media_consumer)

# Find the unified package
find_package(engine2 REQUIRED)

# Create application using any/all targets
add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE 
  Media::media_core2      # Shared library
  Media::media_dev_tools2 # Static utility library
  Media::storage          # Database functionality
)

# Note: Media::asset_converter2 is an executable, not linkable
```

### Runtime Usage

```cpp
#include <media/core.h>
#include <media/dev_tools.h>
#include <storage/storage.h>

int main() {
    // Initialize media system
    media::MediaCore::initialize();
    
    // Use development tools
    auto info = media::DevTools::analyzeFile("video.mp4");
    
    // Store metadata  
    storage::Database db("media.db");
    db.store("video.mp4", info);
    
    media::MediaCore::shutdown();
    return 0;
}
```

## Comparison: Correct vs Incorrect Patterns

###  Correct Pattern (This Example)

```cmake
target_prepare_package(target1 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep1")
target_prepare_package(target2 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep2")
target_prepare_package(target3 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep3")
finalize_package(EXPORT_NAME "shared")
```

**Result**: Single export with all dependencies aggregated.

### L Incorrect Pattern (Don't Use)

```cmake
target_install_package(target1 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep1")  # Finalizes immediately
target_install_package(target2 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep2")  # Overwrites previous
target_install_package(target3 EXPORT_NAME "shared" PUBLIC_DEPENDENCIES "dep3")  # Overwrites previous
```

**Result**: Multiple exports or lost dependencies.

## Benefits of This Pattern

### Dependency Management
- **Automatic Aggregation**: All `PUBLIC_DEPENDENCIES` from all targets combined
- **Deduplication**: Duplicate dependencies automatically removed
- **Single Config**: Consumer gets all dependencies with one `find_package()` call

### Component Flexibility  
- **Per-Target Components**: Each target can have different component assignments
- **Flexible Installation**: Install runtime, development, or tools independently
- **Packaging Options**: Create different packages for different use cases

### Maintenance
- **Single Export**: One config file to maintain instead of multiple
- **Unified Versioning**: All targets share the same version
- **Consistent Namespace**: All targets use the same namespace prefix

## Key Files

- **CMakeLists.txt**: Shows the correct multi-target export pattern
- **include/**: Public API headers for all libraries
- **src/**: Implementation files
- **Generated configs**: Single export containing all targets and dependencies

This example serves as the reference implementation for multi-target CMake packages.