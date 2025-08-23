# CxxModulesSupport.cmake - Centralized C++ modules support detection

include_guard()

function(check_cxx_modules_support out_var)
    set(modules_supported FALSE)
    
    # Check CMake version
    if(CMAKE_VERSION VERSION_LESS "3.28")
        message(WARNING "C++ modules not supported: CMake 3.28+ required (current: ${CMAKE_VERSION})")
        set(${out_var} FALSE PARENT_SCOPE)
        return()
    endif()
    
    # Check compiler support
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "14.0")
            set(modules_supported TRUE)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.0")
            set(modules_supported TRUE)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.34")
            set(modules_supported TRUE)
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        message(WARNING "C++ modules not supported: AppleClang does not support modules (use Homebrew Clang)")
        set(${out_var} FALSE PARENT_SCOPE)
        return()
    endif()
    
    # Check generator support
    if(NOT CMAKE_GENERATOR MATCHES "Ninja" AND NOT CMAKE_GENERATOR MATCHES "Visual Studio")
        message(WARNING "C++ modules not supported: generator ${CMAKE_GENERATOR} not supported (use Ninja or Visual Studio)")
        set(modules_supported FALSE)
    endif()
    
    if(NOT modules_supported)
        message(WARNING "C++ modules not supported: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} with ${CMAKE_GENERATOR}")
    endif()
    
    set(${out_var} ${modules_supported} PARENT_SCOPE)
endfunction()