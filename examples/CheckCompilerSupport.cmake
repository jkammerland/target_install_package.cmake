# CheckCompilerSupport.cmake
# Helper functions for checking compiler version requirements in examples

#[[
check_cxx_modules_support()

Checks if the current compiler supports C++20 modules and exits gracefully if not.
Sets CMAKE_CXX_STANDARD to 20 if not already set.

Usage:
  include(cmake/CheckCompilerSupport.cmake)
  check_cxx_modules_support()
]]
function(check_cxx_modules_support)
    # Ensure C++20 is set if not already configured
    if(NOT CMAKE_CXX_STANDARD)
        set(CMAKE_CXX_STANDARD 20 PARENT_SCOPE)
    endif()
    if(NOT CMAKE_CXX_STANDARD_REQUIRED)
        set(CMAKE_CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
    endif()
    if(NOT CMAKE_CXX_EXTENSIONS)
        set(CMAKE_CXX_EXTENSIONS OFF PARENT_SCOPE)
    endif()

    # Check compiler support for C++20 modules
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "14.0")
            message(WARNING "GCC 14.0 or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
            return()
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.0")
            message(WARNING "Clang 19.0 or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
            return()
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.29")
            message(WARNING "MSVC 19.29 (Visual Studio 2019 16.10) or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
            return()
        endif()
    else()
        message(WARNING "C++20 modules support may not be available with ${CMAKE_CXX_COMPILER_ID}. Skipping modules example.")
        return()
    endif()

    # If we get here, compiler support is adequate
    message(STATUS "C++20 modules support detected with ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
endfunction()

#[[
check_cxx_modules_support_available(result_var)

Checks if the current compiler supports C++20 modules without exiting.
Sets the result variable to TRUE if support is available, FALSE otherwise.

Arguments:
  result_var - Name of variable to store the result (TRUE/FALSE)

Usage:
  check_cxx_modules_support_available(HAS_MODULES_SUPPORT)
  if(HAS_MODULES_SUPPORT)
    # Use modules
  endif()
]]
function(check_cxx_modules_support_available result_var)
    set(has_support FALSE)
    
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "14.0")
            set(has_support TRUE)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.0")
            set(has_support TRUE)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.29")
            set(has_support TRUE)
        endif()
    endif()
    
    set(${result_var} ${has_support} PARENT_SCOPE)
endfunction()

#[[
check_compiler_version(compiler_id min_version feature_name)

Generic function to check if compiler meets minimum version requirement.
Prints warning and returns to caller if requirement not met.

Arguments:
  compiler_id - Target compiler ID (GNU, Clang, MSVC, etc.)
  min_version - Minimum required version string
  feature_name - Human-readable feature name for warning messages

Usage:
  check_compiler_version("GNU" "11.0" "C++20 concepts")
  check_compiler_version("Clang" "15.0" "C++20 modules") 
]]
function(check_compiler_version compiler_id min_version feature_name)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "${compiler_id}")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "${min_version}")
            message(WARNING "${compiler_id} ${min_version} or later is recommended for ${feature_name}. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
            return()
        endif()
        message(STATUS "${feature_name} support detected with ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
endfunction()