# Component Installation Example

This example demonstrates logical runtime components with one shared SDK component for a single `MediaLib` export.

## Features Demonstrated

- **Runtime components**: `COMPONENT Core` installs runtime files into `Core`; `COMPONENT Tools` installs runtime files into `Tools`.
- **Shared SDK component**: headers, static/import libraries, namelinks, and CMake package metadata install into `Development`.
- **Shared export**: all targets are packaged under one `MediaLib` export.
- **Mixed target types**: shared library, static library, and executable.
- **Selective installation**: install runtime pieces separately, or install SDK files through one component.

## Architecture

```
MediaLib package:
├── Core         - libmedia_core runtime files
├── Tools        - asset_converter runtime executable
└── Development  - headers, libmedia_dev_tools.a, namelinks, and MediaLib CMake config files
```

`COMPONENT` does not create a second SDK component. It only names runtime files. The `Development` component carries SDK files for the whole export. Static and interface targets are SDK-only, so they do not create empty runtime packages. For shared-library consumers, install `Development` plus the runtime components, or use native packages configured to honor CPack component dependency metadata.

## Building and Installing

### Configure and Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
cmake --build .
```

### Component-Based Installation

```bash
# Install everything
cmake --install .

# Minimal runtime deployment
cmake --install . --component Core
cmake --install . --component Tools

# SDK files for consumers
cmake --install . --component Development

# Full developer install assembled from components
cmake --install . --component Core
cmake --install . --component Tools
cmake --install . --component Development
```

## Installation Structure

```
install/
├── bin/
│   └── asset_converter                    # Tools
├── include/
│   └── media/
│       ├── core.h                         # Development
│       └── dev_tools.h                    # Development
├── lib64/
│   ├── libmedia_core.so.1.0.0             # Core
│   ├── libmedia_core.so.1                 # Core
│   ├── libmedia_core.so                   # Development namelink
│   └── libmedia_dev_tools.a               # Development
└── share/
    └── cmake/
        └── MediaLib/                      # Development
            ├── MediaLibTargets.cmake
            ├── MediaLibTargets-noconfig.cmake
            ├── MediaLibConfig.cmake
            ├── MediaLibConfigVersion.cmake
            └── MediaLib-config-version.cmake
```

## Component Details

**Core** contains runtime files for the shared library:
- `libmedia_core.so.*`
- No headers or static libraries.

**Tools** contains runtime tools:
- `asset_converter`

**Development** contains SDK files for the export:
- Headers from `media_core` and `media_dev_tools`
- Static/import libraries
- Shared-library namelinks
- CMake package metadata for `find_package(MediaLib)`

## Using the Installed Package

```cmake
cmake_minimum_required(VERSION 3.25)
project(media_app)

find_package(MediaLib REQUIRED)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE
  Media::media_core
  Media::media_dev_tools
)
```

The consumer does not need to know about install components. Install components only control which files are installed into a prefix or package.

## Asset Converter Tool

```bash
./install/bin/asset_converter input.wav output.mp3
./install/bin/asset_converter -f mp3 -q 95 input.wav output.mp3
./install/bin/asset_converter --help
```

## Component Model Features

- **Predictable runtime naming**: `COMPONENT Core` always installs runtime files into `Core`.
- **One SDK component**: `Development` carries the development install tree, while shared-library consumers also need the related runtime components.
- **Logical grouping**: multiple targets can share a runtime component.
- **Shared export**: all targets are packaged under the unified `MediaLib` export.
- **No partial SDK packages**: the shared CMake export is not copied into target-specific SDK components.
