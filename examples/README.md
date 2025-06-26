# CMake Target Install Package Examples

This directory contains comprehensive examples demonstrating the usage of `target_install_package` and `target_configure_sources` utilities.

## 📚 Available Examples

| Example | Type | Features Demonstrated |
|---------|------|----------------------|
| [basic-static](basic-static/) | Static Library | Simple static library with FILE_SET headers |
| [basic-shared](basic-shared/) | Shared Library | Versioned shared library with component separation |
| [basic-interface](basic-interface/) | Interface Library | Header-only template library |
| [multi-target](multi-target/) | Multi-Library | Multiple libraries in one package |
| [components](components/) | Component-Based | Custom components and selective installation |
| [components-same-export](components-same-export/) | Multi-Target Export | Correct pattern for multiple targets with dependency aggregation |
| [dependency-aggregation](dependency-aggregation/) | Dependency Aggregation | Minimal example demonstrating dependency aggregation mechanics |
| [configure-files](configure-files/) | Template Configuration | Build-time header generation from templates |
| [cxx-modules](cxx-modules/) | C++20 Modules | Modern C++20 modules with CXX_MODULES file sets |

## 🚀 Quick Start

Each example is self-contained and can be built independently:

```bash
# Navigate to any example
cd basic-static

# Build and install
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
cmake --build .
cmake --install .
```

## 📖 Learning Path

### 1. Start with Basic Examples

Begin with the basic examples to understand core concepts:

1. **[basic-static](basic-static/)** - Learn fundamental static library packaging
2. **[basic-shared](basic-shared/)** - Understand shared library versioning and components
3. **[basic-interface](basic-interface/)** - Explore header-only library distribution

### 2. Advance to Complex Scenarios

Progress to more sophisticated packaging strategies:

4. **[multi-target](multi-target/)** - Package multiple related libraries together
5. **[components](components/)** - Implement flexible component-based installation
6. **[components-same-export](components-same-export/)** - **Multi-target export with dependency aggregation** (recommended pattern)
7. **[dependency-aggregation](dependency-aggregation/)** - **Minimal dependency aggregation mechanics** (focused example)
8. **[configure-files](configure-files/)** - Generate build-time configuration headers
9. **[cxx-modules](cxx-modules/)** - Explore modern C++20 modules (requires CMake 3.28+)

## 🔧 Common Build Commands

### Standard Build and Install

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install
cmake --build .
cmake --install .
```

### Debug Build with Detailed Logging

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install \
         -DPROJECT_LOG_COLORS=ON \
         --log-level=DEBUG
cmake --build .
cmake --install .
```

### Component-Based Installation

```bash
# Install only runtime components
cmake --install . --component Runtime

# Install only development components  
cmake --install . --component Development

# Install custom components (see components example)
cmake --install . --component runtime --component devel
```

## 📁 Installation Structure

All examples install to `build/install/` by default, creating this typical structure:

```
install/
├── bin/                    # Executables (if any)
├── include/                # Header files
│   └── <library>/         # Library-specific headers
├── lib/                   # Libraries
│   ├── lib<name>.a        # Static libraries
│   ├── lib<name>.so       # Shared libraries (Linux)
│   └── <name>.lib         # Import libraries (Windows)
└── share/
    └── cmake/
        └── <package>/     # CMake configuration files
            ├── <package>-config.cmake
            ├── <package>-config-version.cmake
            └── <package>-targets.cmake
```

## 🎯 Key Features Covered

### Modern CMake Practices

- **FILE_SET**: Modern header management (CMake 3.23+)
- **Generator Expressions**: Build vs install interface separation
- **Component System**: Flexible installation strategies
- **Target Dependencies**: Proper transitive dependency handling

### Package Configuration

- **Config Files**: Automatic CMake package configuration generation
- **Version Compatibility**: SameMajorVersion, ExactVersion, etc.
- **Namespace Support**: Organized target naming
- **Dependency Management**: Automatic dependency finding

### Cross-Platform Support

- **GNUInstallDirs**: Standard installation directories
- **Component Separation**: Runtime vs development file organization

## 🛠️ Example-Specific Features

### Static Library ([basic-static](basic-static/))
- Simple static library packaging
- FILE_SET header installation
- Development component assignment

### Shared Library ([basic-shared](basic-shared/))
- Library versioning (VERSION, SOVERSION)
- Runtime/Development component separation
- Building and packaging shared libraries for different platforms

### Interface Library ([basic-interface](basic-interface/))
- Header-only template library
- No runtime dependencies
- Template algorithm implementations

### Multi-Target ([multi-target](multi-target/))
- Multiple libraries in one package
- ADDITIONAL_TARGETS usage
- Transitive dependency management

### Components ([components](components/))
- Custom component names
- Mixed target types (shared, static, executable)

### Multi-Target Export ([components-same-export](components-same-export/))
- **Recommended pattern** for multiple targets with shared export
- Dependency aggregation from multiple `PUBLIC_DEPENDENCIES`
- Per-target component assignments within single export
- Demonstrates correct `target_prepare_package()` + `finalize_package()` usage

### Dependency Aggregation ([dependency-aggregation](dependency-aggregation/))
- **Minimal focused example** of dependency aggregation mechanics
- Uses real dependencies (fmt, spdlog, cxxopts) via FetchContent
- Demonstrates the difference between correct and problematic patterns
- Shows exactly how dependencies are collected and aggregated

### Configure Files ([configure-files](configure-files/))
- Template file processing
- Build-time variable substitution
- PUBLIC vs PRIVATE configured headers

### C++20 Modules ([cxx-modules](cxx-modules/))
- Modern C++20 module interface units
- CXX_MODULES file set usage
- Module dependency resolution
- Cross-module imports and exports

## 📝 Creating Consumer Projects

After installing any example, create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Add install location to prefix path
list(APPEND CMAKE_PREFIX_PATH "/path/to/example/build/install")

# Find the installed package
find_package(<package_name> REQUIRED)

# Create your application
add_executable(my_app main.cpp)

# Link with the installed library
target_link_libraries(my_app PRIVATE <Namespace>::<target>)
```

## 🔍 Debugging Tips

### Enable Detailed Logging

```bash
cmake .. -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
```

### Check Installation Results

```bash
# Verify installed files
find install/ -type f | sort

# Check CMake config files
cat install/share/cmake/*/*-config.cmake
```

### Test Package Finding

```bash
# Test if package can be found
cmake --find-package -DNAME=<package> -DCOMPILER_ID=GNU -DLANGUAGE=CXX -DMODE=EXIST
```

## 🤝 Contributing

When adding new examples:

1. Follow the established directory structure
2. Include a comprehensive README.md
3. Use `CMAKE_INSTALL_PREFIX=./install` for consistency
4. Demonstrate specific features clearly
5. Provide working consumer code examples

## 📚 Further Reading

- [target_install_package.cmake](../target_install_package.cmake) - Function implementation
- [target_configure_sources.cmake](../target_configure_sources.cmake) - Configuration utilities
- [CMake Documentation](https://cmake.org/cmake/help/latest/) - Official CMake reference