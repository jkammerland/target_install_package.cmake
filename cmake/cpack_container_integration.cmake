cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.6.2)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
endif()

# Ensure project_log is available
if(NOT COMMAND project_log)
  function(project_log level)
    set(msg "")
    if(ARGV)
      list(REMOVE_AT ARGV 0)
      string(JOIN " " msg ${ARGV})
    endif()
    message(${level} "[cpack_container_integration][${level}] ${msg}")
  endfunction()
endif()

# ~~~
# Extended export_cpack function that optionally integrates with export_container.
#
# This function extends the standard export_cpack functionality with optional
# container generation capabilities. It maintains backward compatibility while
# adding container-specific options.
#
# API:
#   export_cpack_with_containers(
#     # All standard export_cpack parameters...
#     [PACKAGE_NAME <name>]
#     [PACKAGE_VENDOR <vendor>]
#     # ... etc ...
#
#     # Container-specific options
#     [CONTAINER_GENERATION <ON|OFF>]
#     [CONTAINER_NAME <name>]
#     [CONTAINER_FROM <base_image>]
#     [CONTAINER_WORKDIR <path>]
#     [CONTAINER_CMD <command>]
#     [CONTAINER_ENV <key=value> ...]
#     [CONTAINER_EXPOSE <port> ...]
#     [CONTAINER_LABELS <key=value> ...]
#     [CONTAINER_USER <user:group>]
#     [CONTAINER_TOOL <podman|docker|buildah>]
#     [CONTAINER_MULTI_STAGE]
#   )
#
# Container Parameters:
#   CONTAINER_GENERATION  - Enable container generation (default: OFF)
#   CONTAINER_NAME       - Container name (default: PACKAGE_NAME)
#   CONTAINER_FROM       - Base image (default: scratch)
#   CONTAINER_WORKDIR    - Working directory (default: /usr/local)
#   CONTAINER_CMD        - Default command
#   CONTAINER_ENV        - Environment variables
#   CONTAINER_EXPOSE     - Ports to expose
#   CONTAINER_LABELS     - OCI labels
#   CONTAINER_USER       - User to run as
#   CONTAINER_TOOL       - Container tool (default: podman)
#   CONTAINER_MULTI_STAGE - Enable multi-stage builds
# ~~~
function(export_cpack_with_containers)
  # Parse container-specific arguments
  set(container_options CONTAINER_GENERATION CONTAINER_MULTI_STAGE)
  set(container_oneValueArgs CONTAINER_NAME CONTAINER_FROM CONTAINER_WORKDIR 
                            CONTAINER_CMD CONTAINER_USER CONTAINER_TOOL)
  set(container_multiValueArgs CONTAINER_ENV CONTAINER_EXPOSE CONTAINER_LABELS)
  
  # Standard export_cpack arguments (subset for brevity)
  set(standard_options COMPONENT_GROUPS ENABLE_COMPONENT_INSTALL NO_DEFAULT_GENERATORS GENERATE_CHECKSUMS)
  set(standard_oneValueArgs PACKAGE_NAME PACKAGE_VERSION PACKAGE_VENDOR PACKAGE_CONTACT 
                           PACKAGE_DESCRIPTION PACKAGE_HOMEPAGE_URL LICENSE_FILE ARCHIVE_FORMAT
                           GPG_SIGNING_KEY GPG_PASSPHRASE_FILE SIGNING_METHOD GPG_KEYSERVER)
  set(standard_multiValueArgs GENERATORS COMPONENTS DEFAULT_COMPONENTS ADDITIONAL_CPACK_VARS)
  
  # Combine all arguments
  set(all_options ${container_options} ${standard_options})
  set(all_oneValueArgs ${container_oneValueArgs} ${standard_oneValueArgs})
  set(all_multiValueArgs ${container_multiValueArgs} ${standard_multiValueArgs})
  
  cmake_parse_arguments(ECWC "${all_options}" "${all_oneValueArgs}" "${all_multiValueArgs}" ${ARGN})
  
  # Set container defaults
  if(NOT DEFINED ECWC_CONTAINER_GENERATION)
    set(ECWC_CONTAINER_GENERATION OFF)
  endif()
  
  if(ECWC_CONTAINER_GENERATION AND NOT ECWC_CONTAINER_NAME)
    set(ECWC_CONTAINER_NAME "${ECWC_PACKAGE_NAME}")
    if(NOT ECWC_CONTAINER_NAME)
      set(ECWC_CONTAINER_NAME "${PROJECT_NAME}")
    endif()
  endif()
  
  project_log(STATUS "Configuring CPack with container integration")
  project_log(VERBOSE "  Container generation: ${ECWC_CONTAINER_GENERATION}")
  if(ECWC_CONTAINER_GENERATION)
    project_log(VERBOSE "  Container name: ${ECWC_CONTAINER_NAME}")
  endif()
  
  # Call standard export_cpack with standard arguments
  set(standard_args "")
  
  # Forward standard options
  foreach(opt ${standard_options})
    if(ECWC_${opt})
      list(APPEND standard_args ${opt})
    endif()
  endforeach()
  
  # Forward standard single-value args
  foreach(arg ${standard_oneValueArgs})
    if(ECWC_${arg})
      list(APPEND standard_args ${arg} "${ECWC_${arg}}")
    endif()
  endforeach()
  
  # Forward standard multi-value args
  foreach(arg ${standard_multiValueArgs})
    if(ECWC_${arg})
      list(APPEND standard_args ${arg} ${ECWC_${arg}})
    endif()
  endforeach()
  
  # Ensure TGZ generator for containers
  if(ECWC_CONTAINER_GENERATION)
    if(NOT ECWC_GENERATORS)
      list(APPEND standard_args GENERATORS "TGZ")
    elseif(NOT "TGZ" IN_LIST ECWC_GENERATORS)
      list(APPEND ECWC_GENERATORS "TGZ")
      # Update the forwarded args
      list(REMOVE_ITEM standard_args GENERATORS)
      list(APPEND standard_args GENERATORS ${ECWC_GENERATORS})
    endif()
    
    # Enable component install for containers
    if(NOT ECWC_ENABLE_COMPONENT_INSTALL)
      list(APPEND standard_args ENABLE_COMPONENT_INSTALL)
    endif()
  endif()
  
  # Call the original export_cpack function
  if(COMMAND export_cpack)
    export_cpack(${standard_args})
  else()
    project_log(WARNING "export_cpack function not available - include export_cpack.cmake first")
  endif()
  
  # Configure container generation if enabled
  if(ECWC_CONTAINER_GENERATION)
    _configure_container_integration("${ECWC_CONTAINER_NAME}" "${ECWC_CONTAINER_FROM}" 
                                    "${ECWC_CONTAINER_WORKDIR}" "${ECWC_CONTAINER_CMD}"
                                    "${ECWC_CONTAINER_USER}" "${ECWC_CONTAINER_TOOL}"
                                    "${ECWC_CONTAINER_MULTI_STAGE}" "${ECWC_CONTAINER_ENV}"
                                    "${ECWC_CONTAINER_EXPOSE}" "${ECWC_CONTAINER_LABELS}")
  endif()
endfunction()

# ~~~
# Internal function to configure container integration.
# ~~~
function(_configure_container_integration container_name container_from container_workdir 
                                         container_cmd container_user container_tool
                                         container_multi_stage container_env container_expose container_labels)
  
  # Check if export_container is available
  if(NOT COMMAND export_container)
    project_log(WARNING "Container generation requested but export_container not available")
    project_log(WARNING "Include export_container.cmake to enable container features")
    return()
  endif()
  
  project_log(STATUS "Setting up container generation for: ${container_name}")
  
  # Build export_container arguments
  set(container_args "")
  
  if(container_name)
    list(APPEND container_args CONTAINER_NAME "${container_name}")
  endif()
  
  if(container_from)
    list(APPEND container_args FROM "${container_from}")
  endif()
  
  if(container_workdir)
    list(APPEND container_args WORKDIR "${container_workdir}")
  endif()
  
  if(container_cmd)
    list(APPEND container_args CMD "${container_cmd}")
  endif()
  
  if(container_user)
    list(APPEND container_args USER "${container_user}")
  endif()
  
  if(container_tool)
    list(APPEND container_args CONTAINER_TOOL "${container_tool}")
  endif()
  
  if(container_multi_stage)
    list(APPEND container_args MULTI_STAGE)
  endif()
  
  if(container_env)
    list(APPEND container_args ENV ${container_env})
  endif()
  
  if(container_expose)
    list(APPEND container_args EXPOSE ${container_expose})
  endif()
  
  if(container_labels)
    list(APPEND container_args LABELS ${container_labels})
  endif()
  
  # Add standard container labels
  if(PROJECT_VERSION)
    list(APPEND container_args LABELS "org.opencontainers.image.version=${PROJECT_VERSION}")
  endif()
  
  if(PROJECT_DESCRIPTION)
    list(APPEND container_args LABELS "org.opencontainers.image.description=${PROJECT_DESCRIPTION}")
  endif()
  
  # Call export_container with the configured arguments
  export_container(${container_args})
  
  project_log(STATUS "Container integration configured for: ${container_name}")
endfunction()

# ~~~
# Convenience macro that adds container-specific options to export_cpack.
#
# This macro allows using container options directly in export_cpack calls
# while maintaining backward compatibility. It's a simpler alternative to
# export_cpack_with_containers for users who want minimal integration.
#
# Usage:
#   enable_cpack_container_integration()
#   export_cpack(
#     PACKAGE_NAME "MyApp"
#     # Standard CPack options...
#     
#     # Container options now available:
#     CONTAINER_GENERATION ON
#     CONTAINER_FROM "scratch"
#     CONTAINER_CMD "/usr/local/bin/myapp"
#   )
# ~~~
macro(enable_cpack_container_integration)
  if(COMMAND export_cpack)
    # Rename the original export_cpack
    cmake_language(CALL function "export_cpack" OUTVAR _original_export_cpack)
    
    # Override export_cpack to use our integrated version
    function(export_cpack)
      export_cpack_with_containers(${ARGN})
    endfunction()
    
    project_log(STATUS "CPack container integration enabled")
  else()
    project_log(WARNING "Cannot enable container integration - export_cpack not available")
  endif()
endmacro()