cmake_minimum_required(VERSION 3.25)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 1.0.0)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
endif()

# Ensure project_log is available (simple fallback if not defined elsewhere)
if(NOT COMMAND project_log)
  function(project_log level)
    set(context "CMake")
    if(PROJECT_NAME)
      set(context "${PROJECT_NAME}")
    endif()
    
    set(msg "")
    if(ARGV)
      list(REMOVE_AT ARGV 0)
      string(JOIN " " msg ${ARGV})
    endif()
    message(${level} "[${context}][${level}] ${msg}")
  endfunction()
endif()

# ~~~
# Collect runtime dependencies for dynamic linking scenarios.
#
# This function registers targets for runtime dependency collection using 
# file(GET_RUNTIME_DEPENDENCIES) and installs collected .so files to a 
# separate RuntimeDeps component to minimize container size by excluding 
# system libraries.
#
# The function uses cmake_language(DEFER) to defer actual collection until
# the end of configuration, allowing multiple targets to be registered
# throughout the configuration phase.
#
# API:
#   collect_rdeps(target1 [target2 ...])
#
# Parameters:
#   target1, target2, ... - Executable or shared library targets to collect dependencies for
#
# Behavior:
#   - Registers targets for runtime dependency collection
#   - Uses file(GET_RUNTIME_DEPENDENCIES) during install time
#   - Filters out system libraries with PRE_EXCLUDE_REGEXES
#   - Installs dependencies to ${CMAKE_INSTALL_LIBDIR} with COMPONENT RuntimeDeps
#   - Follows symlink chains to ensure all necessary files are included
#   - Automatically defers finalization to end of configuration
#
# Integration:
#   - Works with existing target_install_package() workflow
#   - Dependencies are collected in the RuntimeDeps component
#   - Can be used with CPack component-based packaging
#   - Compatible with container workflows for shared library containers
#
# Examples:
#   # Basic usage with executables
#   collect_rdeps(app1 app2 app3)
#
#   # Mixed targets (executables and shared libraries)
#   collect_rdeps(my_app shared_lib1 shared_lib2)
#
#   # Single target
#   collect_rdeps(main_executable)
#
# Notes:
#   - Only works with dynamic linking (BUILD_SHARED_LIBS=ON or mixed scenarios)
#   - System libraries are excluded to keep container size minimal
#   - PRE_EXCLUDE_REGEXES filters: /lib, /usr/lib, /lib64, /usr/lib64
#   - Dependencies are resolved at install time, not configure time
#   - Multiple calls to collect_rdeps() accumulate targets
# ~~~
function(collect_rdeps)
  if(NOT ARGV)
    project_log(WARNING "collect_rdeps() called with no targets")
    return()
  endif()
  
  # Validate that all provided arguments are actual targets
  foreach(target ${ARGV})
    if(NOT TARGET ${target})
      project_log(FATAL_ERROR "collect_rdeps(): '${target}' is not a valid target")
    endif()
  endforeach()
  
  # Store targets in global property for deferred collection
  get_property(existing_targets GLOBAL PROPERTY RDEPS_TARGETS)
  if(existing_targets)
    list(APPEND existing_targets ${ARGV})
  else()
    set(existing_targets ${ARGV})
  endif()
  
  # Remove duplicates
  list(REMOVE_DUPLICATES existing_targets)
  set_property(GLOBAL PROPERTY RDEPS_TARGETS ${existing_targets})
  
  project_log(VERBOSE "Registered targets for runtime dependency collection: ${ARGV}")
  project_log(DEBUG "Total registered targets: ${existing_targets}")
  
  # Schedule finalization at end of configuration (only once)
  get_property(finalization_scheduled GLOBAL PROPERTY RDEPS_FINALIZATION_SCHEDULED)
  if(NOT finalization_scheduled)
    project_log(DEBUG "Scheduling runtime dependency collection finalization")
    cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL _finalize_rdeps)
    set_property(GLOBAL PROPERTY RDEPS_FINALIZATION_SCHEDULED TRUE)
  endif()
endfunction()

# ~~~
# Internal function to finalize runtime dependency collection.
#
# This function is automatically called at the end of configuration via
# cmake_language(DEFER CALL) and should not be called directly.
#
# Implementation details:
#   - Retrieves all registered targets from global property
#   - Creates install(CODE) rule with file(GET_RUNTIME_DEPENDENCIES)
#   - Uses PRE_EXCLUDE_REGEXES to filter system libraries
#   - Installs to ${CMAKE_INSTALL_LIBDIR} with RuntimeDeps component
#   - Follows symlink chains for complete dependency resolution
# ~~~
function(_finalize_rdeps)
  get_property(targets GLOBAL PROPERTY RDEPS_TARGETS)
  
  if(NOT targets)
    project_log(DEBUG "No targets registered for runtime dependency collection")
    return()
  endif()
  
  # Convert targets to full paths for GET_RUNTIME_DEPENDENCIES
  # We need to use generator expressions since target locations aren't known at configure time
  set(target_genexps "")
  foreach(target ${targets})
    get_target_property(target_type ${target} TYPE)
    if(target_type STREQUAL "EXECUTABLE")
      list(APPEND target_genexps "$<TARGET_FILE:${target}>")
    elseif(target_type MATCHES "SHARED_LIBRARY")
      list(APPEND target_genexps "$<TARGET_FILE:${target}>")
    else()
      project_log(WARNING "Target '${target}' is not an executable or shared library, skipping runtime dependency collection")
    endif()
  endforeach()
  
  if(NOT target_genexps)
    project_log(WARNING "No valid targets found for runtime dependency collection")
    return()
  endif()
  
  list(LENGTH targets target_count)
  if(target_count EQUAL 1)
    set(target_word "target")
  else()
    set(target_word "targets")
  endif()
  
  project_log(STATUS "Setting up runtime dependency collection for ${target_count} ${target_word}: ${targets}")
  
  # Create install rule that runs at install time
  # Using a here-document for better readability of the install code
  install(CODE "
    # Runtime dependency collection for targets: ${targets}
    message(STATUS \"Collecting runtime dependencies for: ${targets}\")
    
    # Resolve target paths at install time
    set(resolved_executables)
    foreach(target_path \"${target_genexps}\")
      list(APPEND resolved_executables \"\${target_path}\")
    endforeach()
    
    # Use file(GET_RUNTIME_DEPENDENCIES) to find all .so dependencies
    file(GET_RUNTIME_DEPENDENCIES
      EXECUTABLES \${resolved_executables}
      RESOLVED_DEPENDENCIES_VAR runtime_deps
      UNRESOLVED_DEPENDENCIES_VAR unresolved_deps
      # Exclude system libraries to minimize container size
      # These are standard system library paths that should not be bundled
      PRE_EXCLUDE_REGEXES
        \"^/lib/\"
        \"^/lib64/\"
        \"^/usr/lib/\"
        \"^/usr/lib64/\"
        \"^/System/Library/\"  # macOS system libraries
        \"^/usr/local/lib/\"   # Optional: exclude /usr/local if desired
    )
    
    # Report what was found
    list(LENGTH runtime_deps dep_count)
    if(dep_count GREATER 0)
      message(STATUS \"Found \${dep_count} runtime dependencies to install\")
      foreach(dep \${runtime_deps})
        message(VERBOSE \"  Runtime dependency: \${dep}\")
      endforeach()
    else()
      message(STATUS \"No runtime dependencies found (static linking or all dependencies are system libraries)\")
    endif()
    
    # Report unresolved dependencies as warnings
    if(unresolved_deps)
      message(WARNING \"Unresolved runtime dependencies found:\")
      foreach(unresolved \${unresolved_deps})
        message(WARNING \"  Unresolved: \${unresolved}\")
      endforeach()
    endif()
    
    # Install each dependency to lib directory with RuntimeDeps component
    foreach(dep \${runtime_deps})
      # Use FOLLOW_SYMLINK_CHAIN to ensure we get the actual library files
      # This is important for systems where libraries are symlinked
      file(INSTALL \"\${dep}\" 
        DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}\"
        FOLLOW_SYMLINK_CHAIN
        USE_SOURCE_PERMISSIONS)
      
      # Log successful installation
      get_filename_component(dep_name \"\${dep}\" NAME)
      message(VERBOSE \"  Installed runtime dependency: \${dep_name}\")
    endforeach()
    
    if(dep_count GREATER 0)
      message(STATUS \"Runtime dependency collection complete: \${dep_count} dependencies installed to ${CMAKE_INSTALL_LIBDIR}\")
    endif()
  " COMPONENT RuntimeDeps)
  
  # Register the RuntimeDeps component for CPack integration
  # This allows external tools to detect and work with the runtime dependencies
  get_property(detected_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")
  if(NOT "RuntimeDeps" IN_LIST detected_components)
    list(APPEND detected_components "RuntimeDeps")
    set_property(GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS" "${detected_components}")
    project_log(DEBUG "Registered RuntimeDeps component for CPack integration")
  endif()
  
  project_log(VERBOSE "Runtime dependency collection configured for component: RuntimeDeps")
  project_log(VERBOSE "  Install destination: ${CMAKE_INSTALL_LIBDIR}")
  project_log(VERBOSE "  System library exclusion: enabled")
  project_log(VERBOSE "  Symlink following: enabled")
  
  # Clean up global properties
  set_property(GLOBAL PROPERTY RDEPS_TARGETS "")
  set_property(GLOBAL PROPERTY RDEPS_FINALIZATION_SCHEDULED "")
endfunction()

# ~~~
# Query function to check if runtime dependency collection is configured.
#
# This utility function allows external code to determine if any targets
# have been registered for runtime dependency collection.
#
# API:
#   rdeps_is_configured(<output_var>)
#
# Parameters:
#   output_var - Variable name to store the result (TRUE/FALSE)
#
# Example:
#   rdeps_is_configured(has_rdeps)
#   if(has_rdeps)
#     message(STATUS "Runtime dependency collection is active")
#   endif()
# ~~~
function(rdeps_is_configured output_var)
  get_property(targets GLOBAL PROPERTY RDEPS_TARGETS)
  if(targets)
    set(${output_var} TRUE PARENT_SCOPE)
  else()
    set(${output_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# ~~~
# Query function to get list of registered targets.
#
# This utility function allows external code to inspect which targets
# have been registered for runtime dependency collection.
#
# API:
#   rdeps_get_targets(<output_var>)
#
# Parameters:
#   output_var - Variable name to store the list of targets
#
# Example:
#   rdeps_get_targets(rdep_targets)
#   message(STATUS "Targets with runtime dependency collection: ${rdep_targets}")
# ~~~
function(rdeps_get_targets output_var)
  get_property(targets GLOBAL PROPERTY RDEPS_TARGETS)
  set(${output_var} ${targets} PARENT_SCOPE)
endfunction()