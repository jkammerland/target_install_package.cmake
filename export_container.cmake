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

# Ensure project_log is available (simple fallback if not defined elsewhere)
if(NOT COMMAND project_log)
  function(project_log level)
    set(msg "")
    if(ARGV)
      list(REMOVE_AT ARGV 0)
      string(JOIN " " msg ${ARGV})
    endif()
    message(${level} "[export_container][${level}] ${msg}")
  endfunction()
endif()

include(GNUInstallDirs)

# Set policy for install() DESTINATION path normalization if supported
if(POLICY CMP0177)
  cmake_policy(SET CMP0177 NEW)
endif()

# Global variables to track container configurations
define_property(GLOBAL PROPERTY EXPORT_CONTAINER_CONFIGS
  BRIEF_DOCS "List of container configurations"
  FULL_DOCS "Global list of all export_container configurations for deferred processing")

# ~~~
# Configure container generation alongside CPack packaging.
#
# This function creates custom targets for generating OCI containers from CPack output.
# It integrates with the existing target_install_package and export_cpack workflow
# while providing direct container generation capabilities.
#
# API:
#   export_container(
#     [CONTAINER_NAME name]
#     [BASE_IMAGE image]
#     [FROM scratch|image]
#     [WORKDIR path]
#     [CMD command]
#     [ENTRYPOINT command]
#     [ENV key=value ...]
#     [EXPOSE port ...]
#     [LABELS key=value ...]
#     [VOLUMES path ...]
#     [USER user:group]
#     [COMPONENTS component1 component2 ...]
#     [CONTAINER_TOOL podman|docker|buildah]
#     [MULTI_STAGE]
#     [DOCKERFILE_TEMPLATE path]
#     [OUTPUT_DIR directory]
#     [DEPENDS target1 target2 ...]
#   )
#
# Parameters:
#   CONTAINER_NAME     - Name for the container (default: ${PROJECT_NAME})
#   BASE_IMAGE/FROM    - Base container image (default: scratch)
#   WORKDIR           - Working directory in container (default: /usr/local)
#   CMD               - Default command to run
#   ENTRYPOINT        - Container entrypoint
#   ENV               - Environment variables (key=value format)
#   EXPOSE            - Ports to expose
#   LABELS            - OCI labels (key=value format)
#   VOLUMES           - Volume mount points
#   USER              - User to run as (user:group format)
#   COMPONENTS        - CPack components to include (default: auto-detect)
#   CONTAINER_TOOL    - Container tool to use (default: podman)
#   MULTI_STAGE       - Generate multi-stage containers for each component
#   DOCKERFILE_TEMPLATE - Custom Dockerfile template
#   OUTPUT_DIR        - Output directory for generated files
#   DEPENDS           - Additional targets this container depends on
#
# Generated Targets:
#   ${CONTAINER_NAME}-container          - Build container from CPack output
#   ${CONTAINER_NAME}-container-package  - Build CPack packages first
#   ${CONTAINER_NAME}-dockerfile         - Generate Dockerfile only
# ~~~
function(export_container)
  set(options MULTI_STAGE)
  set(oneValueArgs CONTAINER_NAME BASE_IMAGE FROM WORKDIR CMD ENTRYPOINT USER CONTAINER_TOOL DOCKERFILE_TEMPLATE OUTPUT_DIR)
  set(multiValueArgs ENV EXPOSE LABELS VOLUMES COMPONENTS DEPENDS)
  cmake_parse_arguments(EC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  
  # Set defaults
  if(NOT EC_CONTAINER_NAME)
    set(EC_CONTAINER_NAME "${PROJECT_NAME}")
  endif()
  
  if(NOT EC_FROM)
    if(EC_BASE_IMAGE)
      set(EC_FROM "${EC_BASE_IMAGE}")
    else()
      set(EC_FROM "scratch")
    endif()
  endif()
  
  if(NOT EC_WORKDIR)
    set(EC_WORKDIR "/usr/local")
  endif()
  
  if(NOT EC_CONTAINER_TOOL)
    set(EC_CONTAINER_TOOL "podman")
  endif()
  
  if(NOT EC_OUTPUT_DIR)
    set(EC_OUTPUT_DIR "${CMAKE_BINARY_DIR}/containers")
  endif()
  
  # Auto-detect components if not specified
  if(NOT EC_COMPONENTS)
    get_property(detected_components GLOBAL PROPERTY CPACK_COMPONENTS_ALL)
    if(detected_components)
      set(EC_COMPONENTS ${detected_components})
    else()
      set(EC_COMPONENTS "Runtime")
    endif()
  endif()
  
  # Auto-detect CMD if not specified
  if(NOT EC_CMD AND NOT EC_ENTRYPOINT)
    # Try to find an executable target with the same name
    if(TARGET "${EC_CONTAINER_NAME}")
      get_target_property(target_type "${EC_CONTAINER_NAME}" TYPE)
      if(target_type STREQUAL "EXECUTABLE")
        set(EC_CMD "${EC_WORKDIR}/bin/${EC_CONTAINER_NAME}")
      endif()
    else()
      # Default assumption
      set(EC_CMD "${EC_WORKDIR}/bin/${EC_CONTAINER_NAME}")
    endif()
  endif()
  
  project_log(STATUS "Configuring container export: ${EC_CONTAINER_NAME}")
  project_log(VERBOSE "  From: ${EC_FROM}")
  project_log(VERBOSE "  Workdir: ${EC_WORKDIR}")
  project_log(VERBOSE "  CMD: ${EC_CMD}")
  project_log(VERBOSE "  Components: ${EC_COMPONENTS}")
  project_log(VERBOSE "  Container tool: ${EC_CONTAINER_TOOL}")
  project_log(VERBOSE "  Multi-stage: ${EC_MULTI_STAGE}")
  
  # Store configuration for deferred processing
  set(config_id "${EC_CONTAINER_NAME}")
  set_property(GLOBAL APPEND PROPERTY EXPORT_CONTAINER_CONFIGS "${config_id}")
  
  # Store all configuration in global properties
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_NAME" "${EC_CONTAINER_NAME}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_FROM" "${EC_FROM}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_WORKDIR" "${EC_WORKDIR}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_CMD" "${EC_CMD}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_ENTRYPOINT" "${EC_ENTRYPOINT}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_USER" "${EC_USER}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_COMPONENTS" "${EC_COMPONENTS}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_CONTAINER_TOOL" "${EC_CONTAINER_TOOL}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_MULTI_STAGE" "${EC_MULTI_STAGE}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_DOCKERFILE_TEMPLATE" "${EC_DOCKERFILE_TEMPLATE}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_OUTPUT_DIR" "${EC_OUTPUT_DIR}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_ENV" "${EC_ENV}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_EXPOSE" "${EC_EXPOSE}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_LABELS" "${EC_LABELS}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_VOLUMES" "${EC_VOLUMES}")
  set_property(GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_DEPENDS" "${EC_DEPENDS}")
  
  # Schedule finalization
  cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL _finalize_export_containers)
endfunction()

# ~~~
# Internal function to finalize all export_container configurations.
# This runs at the end of configuration and creates the actual custom targets.
# ~~~
function(_finalize_export_containers)
  get_property(configs GLOBAL PROPERTY EXPORT_CONTAINER_CONFIGS)
  if(NOT configs)
    return()
  endif()
  
  project_log(STATUS "Finalizing container exports...")
  
  foreach(config_id ${configs})
    _create_container_targets("${config_id}")
  endforeach()
  
  project_log(STATUS "Container export finalization complete")
endfunction()

# ~~~
# Internal function to create custom targets for a container configuration.
# ~~~
function(_create_container_targets config_id)
  # Retrieve configuration
  get_property(name GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_NAME")
  get_property(from_image GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_FROM")
  get_property(workdir GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_WORKDIR")
  get_property(cmd GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_CMD")
  get_property(entrypoint GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_ENTRYPOINT")
  get_property(user GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_USER")
  get_property(components GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_COMPONENTS")
  get_property(container_tool GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_CONTAINER_TOOL")
  get_property(multi_stage GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_MULTI_STAGE")
  get_property(dockerfile_template GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_DOCKERFILE_TEMPLATE")
  get_property(output_dir GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_OUTPUT_DIR")
  get_property(env_vars GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_ENV")
  get_property(expose_ports GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_EXPOSE")
  get_property(labels GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_LABELS")
  get_property(volumes GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_VOLUMES")
  get_property(depends GLOBAL PROPERTY "EXPORT_CONTAINER_${config_id}_DEPENDS")
  
  # Create output directory
  file(MAKE_DIRECTORY "${output_dir}")
  
  if(multi_stage)
    _create_multi_stage_targets("${name}" "${from_image}" "${workdir}" "${cmd}" "${entrypoint}" 
                               "${user}" "${components}" "${container_tool}" "${output_dir}"
                               "${env_vars}" "${expose_ports}" "${labels}" "${volumes}" "${depends}")
  else()
    _create_single_stage_targets("${name}" "${from_image}" "${workdir}" "${cmd}" "${entrypoint}"
                                "${user}" "${components}" "${container_tool}" "${output_dir}"
                                "${env_vars}" "${expose_ports}" "${labels}" "${volumes}" "${depends}")
  endif()
endfunction()

# ~~~
# Create single-stage container targets.
# ~~~
function(_create_single_stage_targets name from_image workdir cmd entrypoint user components container_tool output_dir env_vars expose_ports labels volumes depends)
  project_log(VERBOSE "Creating single-stage container targets for: ${name}")
  
  # Generate container build script
  set(build_script "${output_dir}/${name}-build.sh")
  _generate_container_build_script("${build_script}" "${name}" "${from_image}" "${workdir}" 
                                   "${cmd}" "${entrypoint}" "${user}" "${components}" "${container_tool}"
                                   "${env_vars}" "${expose_ports}" "${labels}" "${volumes}")
  
  # Create package target that depends on CPack
  add_custom_target(${name}-container-package
    COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Building CPack packages for ${name} container"
    VERBATIM
  )
  
  # Add dependencies if specified
  if(depends)
    add_dependencies(${name}-container-package ${depends})
  endif()
  
  # Create container build target
  add_custom_target(${name}-container
    COMMAND bash "${build_script}"
    DEPENDS ${name}-container-package
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Building ${name} container with ${container_tool}"
    VERBATIM
  )
  
  # Create dockerfile generation target
  if(from_image STREQUAL "scratch")
    set(dockerfile_content "# Dockerfile for ${name}\n# Generated by export_container\n\n")
  else()
    set(dockerfile_content "FROM ${from_image}\n\n")
  endif()
  
  if(from_image STREQUAL "scratch")
    string(APPEND dockerfile_content "# Add CPack tarball as single layer\n")
    string(APPEND dockerfile_content "ADD packages/*.tar.gz /\n\n")
  else()
    string(APPEND dockerfile_content "# Extract CPack tarball\n")
    string(APPEND dockerfile_content "COPY packages/ /tmp/packages/\n")
    string(APPEND dockerfile_content "RUN cd /tmp/packages && tar -xzf *.tar.gz -C / && rm -rf /tmp/packages\n\n")
  endif()
  
  if(workdir)
    string(APPEND dockerfile_content "WORKDIR ${workdir}\n")
  endif()
  
  if(env_vars)
    foreach(env_var ${env_vars})
      string(APPEND dockerfile_content "ENV ${env_var}\n")
    endforeach()
    string(APPEND dockerfile_content "\n")
  endif()
  
  if(expose_ports)
    foreach(port ${expose_ports})
      string(APPEND dockerfile_content "EXPOSE ${port}\n")
    endforeach()
    string(APPEND dockerfile_content "\n")
  endif()
  
  if(labels)
    foreach(label ${labels})
      string(APPEND dockerfile_content "LABEL ${label}\n")
    endforeach()
    string(APPEND dockerfile_content "\n")
  endif()
  
  if(volumes)
    foreach(volume ${volumes})
      string(APPEND dockerfile_content "VOLUME ${volume}\n")
    endforeach()
    string(APPEND dockerfile_content "\n")
  endif()
  
  if(user)
    string(APPEND dockerfile_content "USER ${user}\n")
  endif()
  
  if(entrypoint)
    string(APPEND dockerfile_content "ENTRYPOINT [\"${entrypoint}\"]\n")
  endif()
  
  if(cmd)
    string(APPEND dockerfile_content "CMD [\"${cmd}\"]\n")
  endif()
  
  set(dockerfile "${output_dir}/Dockerfile.${name}")
  file(WRITE "${dockerfile}" "${dockerfile_content}")
  
  add_custom_target(${name}-dockerfile
    COMMAND ${CMAKE_COMMAND} -E echo "Generated Dockerfile: ${dockerfile}"
    COMMENT "Dockerfile generated for ${name}"
    VERBATIM
  )
  
  project_log(STATUS "Created container targets: ${name}-container, ${name}-container-package, ${name}-dockerfile")
endfunction()

# ~~~
# Create multi-stage container targets (one per component).
# ~~~
function(_create_multi_stage_targets name from_image workdir cmd entrypoint user components container_tool output_dir env_vars expose_ports labels volumes depends)
  project_log(VERBOSE "Creating multi-stage container targets for: ${name}")
  
  foreach(component ${components})
    string(TOLOWER "${component}" component_lower)
    set(stage_name "${name}-${component_lower}")
    
    # Determine component-specific configuration
    set(stage_cmd "${cmd}")
    set(stage_entrypoint "${entrypoint}")
    
    if(component STREQUAL "Development")
      set(stage_cmd "/bin/sh")
      set(stage_entrypoint "")
    elseif(component STREQUAL "Tools")
      set(stage_cmd "${workdir}/bin/${name}_tool")
    endif()
    
    # Generate component-specific build script
    set(build_script "${output_dir}/${stage_name}-build.sh")
    _generate_component_build_script("${build_script}" "${stage_name}" "${from_image}" "${workdir}"
                                     "${stage_cmd}" "${stage_entrypoint}" "${user}" "${component}" "${container_tool}"
                                     "${env_vars}" "${expose_ports}" "${labels}" "${volumes}")
    
    # Create component container target
    add_custom_target(${stage_name}-container
      COMMAND bash "${build_script}"
      DEPENDS ${name}-container-package
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      COMMENT "Building ${stage_name} container with ${container_tool}"
      VERBATIM
    )
    
    project_log(VERBOSE "Created container target: ${stage_name}-container")
  endforeach()
  
  # Create aggregate target
  set(all_stage_targets "")
  foreach(component ${components})
    string(TOLOWER "${component}" component_lower)
    list(APPEND all_stage_targets "${name}-${component_lower}-container")
  endforeach()
  
  add_custom_target(${name}-container
    DEPENDS ${all_stage_targets}
    COMMENT "Building all ${name} container stages"
  )
  
  # Still create the package target
  add_custom_target(${name}-container-package
    COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Building CPack packages for ${name} containers"
    VERBATIM
  )
  
  if(depends)
    add_dependencies(${name}-container-package ${depends})
  endif()
  
  project_log(STATUS "Created multi-stage container targets for: ${name}")
endfunction()

# ~~~
# Generate container build script for single-stage containers.
# ~~~
function(_generate_container_build_script script_path name from_image workdir cmd entrypoint user components container_tool env_vars expose_ports labels volumes)
  set(script_content "#!/bin/bash\n")
  string(APPEND script_content "set -e\n\n")
  string(APPEND script_content "# Container build script for ${name}\n")
  string(APPEND script_content "# Generated by export_container\n\n")
  
  string(APPEND script_content "CONTAINER_TOOL=\"${container_tool}\"\n")
  string(APPEND script_content "CONTAINER_NAME=\"${name}\"\n")
  string(APPEND script_content "BUILD_DIR=\"${CMAKE_BINARY_DIR}\"\n\n")
  
  string(APPEND script_content "echo \"Building ${name} container...\"\n\n")
  
  # Find CPack tarball
  string(APPEND script_content "# Find CPack tarball\n")
  string(APPEND script_content "TARBALL=\\$(find \"\\$BUILD_DIR\" -name \"*.tar.gz\" | head -n1)\n")
  string(APPEND script_content "if [[ -z \"\\$TARBALL\" ]]; then\n")
  string(APPEND script_content "    echo \"Error: No tarball found. Run cpack first.\"\n")
  string(APPEND script_content "    exit 1\n")
  string(APPEND script_content "fi\n\n")
  
  string(APPEND script_content "echo \"Using tarball: \\$TARBALL\"\n\n")
  
  # Build import command
  string(APPEND script_content "# Import container\n")
  string(APPEND script_content "\\$CONTAINER_TOOL import \\\\\n")
  
  if(workdir)
    string(APPEND script_content "    --change \"WORKDIR ${workdir}\" \\\\\n")
  endif()
  
  if(env_vars)
    foreach(env_var ${env_vars})
      string(APPEND script_content "    --change \"ENV ${env_var}\" \\\\\n")
    endforeach()
  endif()
  
  if(expose_ports)
    foreach(port ${expose_ports})
      string(APPEND script_content "    --change \"EXPOSE ${port}\" \\\\\n")
    endforeach()
  endif()
  
  if(labels)
    foreach(label ${labels})
      string(APPEND script_content "    --change \"LABEL ${label}\" \\\\\n")
    endforeach()
  endif()
  
  if(volumes)
    foreach(volume ${volumes})
      string(APPEND script_content "    --change \"VOLUME ${volume}\" \\\\\n")
    endforeach()
  endif()
  
  if(user)
    string(APPEND script_content "    --change \"USER ${user}\" \\\\\n")
  endif()
  
  if(entrypoint)
    string(APPEND script_content "    --change \"ENTRYPOINT [\\\"${entrypoint}\\\"]\" \\\\\n")
  endif()
  
  if(cmd)
    string(APPEND script_content "    --change \"CMD [\\\"${cmd}\\\"]\" \\\\\n")
  endif()
  
  string(APPEND script_content "    \"\\$TARBALL\" \\\\\n")
  string(APPEND script_content "    \"\\$CONTAINER_NAME:latest\"\n\n")
  
  string(APPEND script_content "echo \"Successfully created container: \\$CONTAINER_NAME:latest\"\n")
  string(APPEND script_content "echo \"Test with: \\$CONTAINER_TOOL run --rm \\$CONTAINER_NAME:latest\"\n")
  
  file(WRITE "${script_path}" "${script_content}")
  
  # Make executable
  file(COPY "${script_path}" DESTINATION "${CMAKE_BINARY_DIR}/containers"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
endfunction()

# ~~~
# Generate container build script for component-specific containers.
# ~~~
function(_generate_component_build_script script_path stage_name from_image workdir cmd entrypoint user component container_tool env_vars expose_ports labels volumes)
  set(script_content "#!/bin/bash\n")
  string(APPEND script_content "set -e\n\n")
  string(APPEND script_content "# Container build script for ${stage_name}\n")
  string(APPEND script_content "# Generated by export_container\n\n")
  
  string(APPEND script_content "CONTAINER_TOOL=\"${container_tool}\"\n")
  string(APPEND script_content "STAGE_NAME=\"${stage_name}\"\n")
  string(APPEND script_content "COMPONENT=\"${component}\"\n")
  string(APPEND script_content "BUILD_DIR=\"${CMAKE_BINARY_DIR}\"\n\n")
  
  string(APPEND script_content "echo \"Building ${stage_name} container (${component} component)...\"\n\n")
  
  # Find component-specific tarball
  string(APPEND script_content "# Find component tarball\n")
  string(APPEND script_content "TARBALL=\\$(find \"\\$BUILD_DIR\" -name \"*-${component}.tar.gz\" | head -n1)\n")
  string(APPEND script_content "if [[ -z \"\\$TARBALL\" ]]; then\n")
  string(APPEND script_content "    echo \"Warning: No ${component} tarball found, trying generic tarball...\"\n")
  string(APPEND script_content "    TARBALL=\\$(find \"\\$BUILD_DIR\" -name \"*.tar.gz\" | head -n1)\n")
  string(APPEND script_content "fi\n\n")
  
  string(APPEND script_content "if [[ -z \"\\$TARBALL\" ]]; then\n")
  string(APPEND script_content "    echo \"Error: No tarball found. Run cpack first.\"\n")
  string(APPEND script_content "    exit 1\n")
  string(APPEND script_content "fi\n\n")
  
  string(APPEND script_content "echo \"Using tarball: \\$TARBALL\"\n\n")
  
  # Component-specific environment setup
  if(component STREQUAL "Development")
    string(APPEND script_content "# Development container specific setup\n")
    string(APPEND script_content "DEV_ENV=(\"PKG_CONFIG_PATH=/usr/local/lib/pkgconfig\")\n")
  endif()
  
  # Build import command
  string(APPEND script_content "# Import container\n")
  string(APPEND script_content "\\$CONTAINER_TOOL import \\\\\n")
  
  if(workdir)
    string(APPEND script_content "    --change \"WORKDIR ${workdir}\" \\\\\n")
  endif()
  
  # Add standard library path
  string(APPEND script_content "    --change \"ENV LD_LIBRARY_PATH=${workdir}/lib\" \\\\\n")
  
  if(env_vars)
    foreach(env_var ${env_vars})
      string(APPEND script_content "    --change \"ENV ${env_var}\" \\\\\n")
    endforeach()
  endif()
  
  # Component-specific environment
  if(component STREQUAL "Development")
    string(APPEND script_content "    --change \"ENV PKG_CONFIG_PATH=${workdir}/lib/pkgconfig\" \\\\\n")
  endif()
  
  if(expose_ports)
    foreach(port ${expose_ports})
      string(APPEND script_content "    --change \"EXPOSE ${port}\" \\\\\n")
    endforeach()
  endif()
  
  # Add component-specific labels
  string(APPEND script_content "    --change \"LABEL org.opencontainers.image.component=${component}\" \\\\\n")
  
  if(labels)
    foreach(label ${labels})
      string(APPEND script_content "    --change \"LABEL ${label}\" \\\\\n")
    endforeach()
  endif()
  
  if(volumes)
    foreach(volume ${volumes})
      string(APPEND script_content "    --change \"VOLUME ${volume}\" \\\\\n")
    endforeach()
  endif()
  
  if(user)
    string(APPEND script_content "    --change \"USER ${user}\" \\\\\n")
  endif()
  
  if(entrypoint)
    string(APPEND script_content "    --change \"ENTRYPOINT [\\\"${entrypoint}\\\"]\" \\\\\n")
  endif()
  
  if(cmd)
    string(APPEND script_content "    --change \"CMD [\\\"${cmd}\\\"]\" \\\\\n")
  endif()
  
  string(APPEND script_content "    \"\\$TARBALL\" \\\\\n")
  string(APPEND script_content "    \"\\$STAGE_NAME:latest\"\n\n")
  
  string(APPEND script_content "echo \"Successfully created container: \\$STAGE_NAME:latest\"\n")
  string(APPEND script_content "echo \"Test with: \\$CONTAINER_TOOL run --rm \\$STAGE_NAME:latest\"\n")
  
  file(WRITE "${script_path}" "${script_content}")
  
  # Make executable
  file(COPY "${script_path}" DESTINATION "${CMAKE_BINARY_DIR}/containers"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE)
endfunction()