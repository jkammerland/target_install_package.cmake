# Custom Alias Name Example

This example demonstrates how to use the `ALIAS_NAME` parameter to create custom exported target names that differ from the actual target names.

## Problem Being Solved

By default, when you install a target named `cbor_tags` with namespace `cbor::`, consumers would need to use:
```cmake
find_package(cbor_tags REQUIRED)
target_link_libraries(my_app PRIVATE cbor::cbor_tags)  # Redundant naming
```

With `ALIAS_NAME`, you can create cleaner, more intuitive names:
```cmake
find_package(cbor_tags REQUIRED)
target_link_libraries(my_app PRIVATE cbor::tags)  # Clean and intuitive
```

## Examples in This Project

### 1. Single Target with Underscore Name
- **Target**: `cbor_tags`
- **Exported as**: `cbor::tags`
- **Consumer usage**: `target_link_libraries(app PRIVATE cbor::tags)`

### 2. Library with Version Suffix
- **Target**: `json_parser_v2`
- **Exported as**: `json::parser`
- **Consumer usage**: `target_link_libraries(app PRIVATE json::parser)`

### 3. Multi-Target Package
- **Targets**: `data_core` and `data_utils`
- **Exported as**: `data::core` and `data::utils`
- **Consumer usage**:
  ```cmake
  find_package(data_package REQUIRED)
  target_link_libraries(app PRIVATE 
    data::core
    data::utils
  )
  ```

## Building and Installing

```bash
# Configure
cmake -B build -DCMAKE_INSTALL_PREFIX=./install

# Build
cmake --build build

# Install
cmake --install build
```

## Using the Installed Packages

Create a consumer project with:

```cmake
cmake_minimum_required(VERSION 3.23)
project(consumer)

# Find the packages
find_package(cbor_tags REQUIRED)
find_package(json_parser_v2 REQUIRED)
find_package(data_package REQUIRED)

add_executable(my_app main.cpp)

# Use the clean alias names
target_link_libraries(my_app PRIVATE
  cbor::tags        # Instead of cbor_tags::cbor_tags
  json::parser      # Instead of json_parser_v2::json_parser_v2
  data::core        # Instead of data_core::data_core
  data::utils       # Instead of data_utils::data_utils
)
```

## Benefits

1. **Cleaner API**: No redundant namespace/name combinations
2. **Version Independence**: Can change internal target names without affecting consumers
3. **Better Organization**: Group related targets under intuitive namespaces
4. **Migration Path**: Can rename targets internally while maintaining backward compatibility