# Common utility functions for universal packaging
# This file contains reusable functions to reduce code duplication

# ~~~
# Parse a key-value list and set variables with optional prefix
#
# Usage:
#   _parse_key_value_list(list_var prefix)
#
# Parameters:
#   list_var - Name of the list variable containing key-value pairs
#   prefix   - Optional prefix for the output variables
#
# Example:
#   set(my_list "NAME" "myproject" "VERSION" "1.0.0")
#   _parse_key_value_list(my_list "PKG_")
#   # Results in: PKG_NAME="myproject", PKG_VERSION="1.0.0"
# ~~~
function(_parse_key_value_list list_var prefix)
  list(LENGTH ${list_var} list_length)
  
  if(list_length EQUAL 0)
    return()
  endif()
  
  math(EXPR pairs_count "${list_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")
  
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    
    list(GET ${list_var} ${key_index} key)
    list(GET ${list_var} ${value_index} value)
    
    set(${prefix}${key} "${value}" PARENT_SCOPE)
  endforeach()
endfunction()

# ~~~
# Extract a specific value from a key-value list
#
# Usage:
#   _extract_from_key_value_list(list_var key_name output_var)
#
# Parameters:
#   list_var   - Name of the list variable containing key-value pairs
#   key_name   - The key to search for
#   output_var - Variable to store the found value
# ~~~
function(_extract_from_key_value_list list_var key_name output_var)
  list(LENGTH ${list_var} list_length)
  math(EXPR pairs_count "${list_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")
  
  set(found_value "")
  
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    
    list(GET ${list_var} ${key_index} key)
    
    if(key STREQUAL "${key_name}")
      list(GET ${list_var} ${value_index} found_value)
      break()
    endif()
  endforeach()
  
  set(${output_var} "${found_value}" PARENT_SCOPE)
endfunction()

# ~~~
# Process a template file with variable substitutions
#
# Usage:
#   _process_template_file(template_path output_path substitution_map)
#
# Parameters:
#   template_path    - Path to the template file (relative to templates dir)
#   output_path      - Full path where to write the processed file
#   substitution_map - List of KEY=VALUE pairs for substitution
# ~~~
function(_process_template_file template_path output_path substitution_map)
  # Construct full template path
  set(full_template_path "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/${template_path}")
  
  if(NOT EXISTS "${full_template_path}")
    message(FATAL_ERROR "Template not found: ${full_template_path}")
  endif()
  
  # Read template content
  file(READ "${full_template_path}" content)
  
  # Apply substitutions
  foreach(substitution ${substitution_map})
    # Parse KEY=VALUE format
    string(FIND "${substitution}" "=" delimiter_pos)
    if(delimiter_pos EQUAL -1)
      message(WARNING "Invalid substitution format: ${substitution}")
      continue()
    endif()
    
    string(SUBSTRING "${substitution}" 0 ${delimiter_pos} key)
    math(EXPR value_start "${delimiter_pos} + 1")
    string(SUBSTRING "${substitution}" ${value_start} -1 value)
    
    # Replace @KEY@ with VALUE
    string(REPLACE "@${key}@" "${value}" content "${content}")
  endforeach()
  
  # Write processed content
  file(WRITE "${output_path}" "${content}")
endfunction()

# ~~~
# Create helper scripts for a platform
#
# Usage:
#   _create_platform_helper_scripts(platform output_dir)
#
# Parameters:
#   platform   - Platform name (arch, alpine, nix)
#   output_dir - Directory where to create the scripts
# ~~~
function(_create_platform_helper_scripts platform output_dir)
  foreach(script IN ITEMS build clean install)
    set(template_path "${platform}/${script}.sh.in")
    set(output_path "${output_dir}/${script}.sh")
    
    # No substitutions needed for helper scripts
    _process_template_file("${template_path}" "${output_path}" "")
    
    # Make executable
    execute_process(COMMAND chmod +x "${output_path}")
  endforeach()
  
  message(STATUS "Created ${platform} helper scripts")
endfunction()

# ~~~
# Format a dependency line for package files
#
# Usage:
#   _format_dependency_line(deps_var line_prefix line_suffix wrap_char output_var)
#
# Parameters:
#   deps_var     - Variable containing dependencies (list or string)
#   line_prefix  - Prefix for the line (e.g., "depends=(")
#   line_suffix  - Suffix for the line (e.g., ")")
#   wrap_char    - Character to wrap items (e.g., "" or "'")
#   output_var   - Variable to store the formatted line
#
# Example:
#   _format_dependency_line(ARCH_DEPENDS "depends=(" ")" "" ARCH_DEPENDS_LINE)
# ~~~
function(_format_dependency_line deps_var line_prefix line_suffix wrap_char output_var)
  if(NOT ${deps_var})
    set(${output_var} "" PARENT_SCOPE)
    return()
  endif()
  
  # Convert to space-separated string if it's a list
  string(REPLACE ";" " " deps_str "${${deps_var}}")
  
  # Format the line
  if(wrap_char)
    # Wrap each item
    string(REPLACE " " "${wrap_char} ${wrap_char}" deps_str "${wrap_char}${deps_str}${wrap_char}")
  endif()
  
  set(${output_var} "${line_prefix}${deps_str}${line_suffix}" PARENT_SCOPE)
endfunction()

# ~~~
# Build a substitution map from multiple sources
#
# Usage:
#   _build_substitution_map(output_var metadata_list platform_vars custom_vars)
#
# Parameters:
#   output_var     - Variable to store the substitution map
#   metadata_list  - Universal metadata key-value list
#   platform_vars  - Platform-specific variables (list of KEY=VALUE)
#   custom_vars    - Additional custom variables (list of KEY=VALUE)
# ~~~
function(_build_substitution_map output_var metadata_list platform_vars custom_vars)
  set(substitution_map)
  
  # Add metadata variables
  list(LENGTH metadata_list metadata_length)
  if(metadata_length GREATER 0)
    math(EXPR pairs_count "${metadata_length} / 2")
    
    if(pairs_count GREATER 0)
      math(EXPR max_index "${pairs_count} - 1")
      
      foreach(i RANGE ${max_index})
        math(EXPR key_index "${i} * 2")
        math(EXPR value_index "${key_index} + 1")
        
        list(GET metadata_list ${key_index} key)
        list(GET metadata_list ${value_index} value)
        
        list(APPEND substitution_map "${key}=${value}")
      endforeach()
    endif()
  endif()
  
  # Add platform variables
  if(platform_vars)
    list(APPEND substitution_map ${platform_vars})
  endif()
  
  # Add custom variables
  if(custom_vars)
    list(APPEND substitution_map ${custom_vars})
  endif()
  
  set(${output_var} "${substitution_map}" PARENT_SCOPE)
endfunction()

# ~~~
# Validate required parameters and provide helpful error messages
#
# Usage:
#   _validate_required_params(prefix param1 param2 ...)
#
# Parameters:
#   prefix - Prefix for parameter variables (e.g., "ARG_")
#   params - List of required parameter names
# ~~~
function(_validate_required_params prefix)
  foreach(param ${ARGN})
    if(NOT ${prefix}${param})
      message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: ${param} is required")
    endif()
  endforeach()
endfunction()

# ~~~
# Convert a list to a space-separated string
#
# Usage:
#   _list_to_space_string(input_var output_var)
# ~~~
function(_list_to_space_string input_var output_var)
  if(${input_var})
    string(REPLACE ";" " " result "${${input_var}}")
  else()
    set(result "")
  endif()
  set(${output_var} "${result}" PARENT_SCOPE)
endfunction()