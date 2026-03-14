# Windows DLL Handling

DLLs are co-located with executables by default when using `target_install_package()`. The section below is relevant if you want to consume the package from a custom location **NOT** on your PATH.

## The Problem

On Windows, executables cannot automatically find shared libraries (DLLs) at runtime like they can on Linux/macOS. If you find_package(...) to link a shared library, the DLLs must be on your PATH or in the same directory as the executable.

- **Linux/macOS**: `target_install_package` automatically configures RPATH/RUNPATH (see [RPATH Usage Guide](RPATH-Usage-Guide.md))
- **Windows**: No RPATH mechanism exists - DLLs must be co-located with executables or in PATH

## Solutions

### 1. POST_BUILD DLL Copying

When building test executables that link to shared libraries from installed packages, use CMake's `TARGET_RUNTIME_DLLS` generator expression to copy required DLLs:

```cmake
# Windows: No RPATH mechanism exists - DLLs must be co-located with executables or in PATH
if(WIN32)
  add_custom_command(
    TARGET test_examples_main
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:test_examples_main> $<TARGET_RUNTIME_DLLS:test_examples_main>
    COMMAND_EXPAND_LISTS)
endif()
```

**How It Works:**
1. `$<TARGET_RUNTIME_DLLS:target>` expands to a list of all DLL paths the target depends on
2. `$<TARGET_FILE_DIR:target>` is the directory containing the executable  
3. The command copies all required DLLs next to the executable after building
4. `COMMAND_EXPAND_LISTS` ensures the semicolon-delimited DLL list is properly expanded

### 2. Installation-time Dependency Resolution

Use CMake's `install(RUNTIME_DEPENDENCIES)` for more sophisticated dependency resolution during installation:

```cmake
install(TARGETS test_examples_main DESTINATION bin
  RUNTIME_DEPENDENCIES
    PRE_INCLUDE_REGEXES "mydll.*\.dll$"
    PRE_EXCLUDE_REGEXES ".*"
    DIRECTORIES "${CMAKE_PREFIX_PATH}/bin"
)
```

**How It Works:**
- Analyzes executable dependencies at install time
- Supports regex filtering for inclusion/exclusion
- Can search specific directories for dependencies
- Handles dependency chains automatically

### 3. Manual DLL Management

Explicitly copy specific DLLs using custom commands:

```cmake
find_file(MYDLL_PATH mydll.dll HINTS ${CMAKE_PREFIX_PATH}/bin)
if(WIN32 AND MYDLL_PATH)
  add_custom_command(TARGET test_examples_main POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${MYDLL_PATH}"
      "$<TARGET_FILE_DIR:test_examples_main>"
  )
endif()
```

**How It Works:**
- Find specific DLL files using `find_file()`
- Copy individual DLLs with `copy_if_different`
- Provides precise control over which DLLs are deployed

### 4. PATH-based Discovery

Modify PATH environment to include DLL directories:

```cmake
if(WIN32)
  set_tests_properties(my_test PROPERTIES
    ENVIRONMENT "PATH=${CMAKE_PREFIX_PATH}/bin;$ENV{PATH}")
endif()
```
