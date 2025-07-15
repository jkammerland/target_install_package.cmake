# Alpine Linux specific packaging functions

include(${CMAKE_CURRENT_LIST_DIR}/packaging_utils.cmake)

# ~~~
# Generate Alpine Linux packaging templates
#
# This is the main entry point for Alpine Linux packaging generation.
# ~~~
function(generate_alpine_packaging_templates output_dir components source_packages binary_packages)
  message(STATUS "Generating Alpine Linux templates...")
  
  # Create alpine-specific directory
  set(alpine_dir "${output_dir}/alpine")
  file(MAKE_DIRECTORY "${alpine_dir}")
  
  # Get universal and alpine-specific metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")
  get_property(alpine_config GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_ALPINE_CONFIG")
  
  # Create APKBUILD template
  if(source_packages)
    _create_alpine_apkbuild("${alpine_dir}" "${components}" "${metadata}" "${alpine_config}" FALSE)
  endif()
  
  if(binary_packages)
    _create_alpine_apkbuild("${alpine_dir}" "${components}" "${metadata}" "${alpine_config}" TRUE)
  endif()
  
  # Create helper scripts
  _create_platform_helper_scripts("alpine" "${alpine_dir}")
endfunction()

# ~~~
# Create APKBUILD template for Alpine Linux
# ~~~
function(_create_alpine_apkbuild output_dir components metadata alpine_config is_binary)
  # Parse metadata into variables
  _parse_key_value_list(metadata "")
  
  # Parse alpine config into ALPINE_ prefixed variables
  _parse_key_value_list(alpine_config "ALPINE_")
  
  # Set defaults
  if(NOT ALPINE_ARCH)
    set(ALPINE_ARCH "all")
  endif()
  
  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/APKBUILD-binary")
  else()
    set(filename "${output_dir}/APKBUILD")
  endif()
  
  # Build platform-specific variables
  set(platform_vars)
  
  # Architecture
  list(APPEND platform_vars "ALPINE_ARCH=${ALPINE_ARCH}")
  
  # Dependencies
  _format_dependency_line(ALPINE_DEPENDS "depends=\"" "\"" "" depends_line)
  list(APPEND platform_vars "ALPINE_DEPENDS_LINE=${depends_line}")
  
  _format_dependency_line(ALPINE_MAKEDEPENDS "makedepends=\"" "\"" "" makedepends_line)
  list(APPEND platform_vars "ALPINE_MAKEDEPENDS_LINE=${makedepends_line}")
  
  _format_dependency_line(ALPINE_CHECKDEPENDS "checkdepends=\"" "\"" "" checkdepends_line)
  list(APPEND platform_vars "ALPINE_CHECKDEPENDS_LINE=${checkdepends_line}")
  
  # Source section
  if(NOT is_binary AND SOURCE_URL)
    set(source_section "source=\"${SOURCE_URL}\"
sha256sums=('SKIP')  # Replace with actual checksum")
  else()
    set(source_section "")
  endif()
  list(APPEND platform_vars "ALPINE_SOURCE_SECTION=${source_section}")
  
  # Prepare function
  if(ALPINE_CUSTOM_PREPARE)
    set(prepare_function "prepare() {
    default_prepare
    cd \"${SOURCE_DIR}\"

    # Custom prepare commands
    ${ALPINE_CUSTOM_PREPARE}
}")
  else()
    set(prepare_function "")
  endif()
  list(APPEND platform_vars "ALPINE_PREPARE_FUNCTION=${prepare_function}")
  
  # Build function
  if(NOT is_binary)
    set(build_function "build() {
    cd \"${SOURCE_DIR}\"

    # Default CMake build
    cmake -B build \\
        -DCMAKE_BUILD_TYPE=Release \\
        -DCMAKE_INSTALL_PREFIX=/usr \\
        -DCMAKE_INSTALL_LIBDIR=lib")
    
    if(ALPINE_CUSTOM_BUILD)
      set(build_function "${build_function}

    # Custom build commands
    ${ALPINE_CUSTOM_BUILD}")
    endif()
    
    set(build_function "${build_function}

    cmake --build build
}")
  else()
    set(build_function "")
  endif()
  list(APPEND platform_vars "ALPINE_BUILD_FUNCTION=${build_function}")
  
  # Check function
  if(NOT is_binary)
    set(check_function "check() {
    cd \"${SOURCE_DIR}\"

    # Run tests if available
    cmake --build build --target test || true
}")
  else()
    set(check_function "")
  endif()
  list(APPEND platform_vars "ALPINE_CHECK_FUNCTION=${check_function}")
  
  # Package function content
  if(NOT is_binary)
    set(package_content "    cd \"${SOURCE_DIR}\"

    # Install using CMake
    DESTDIR=\"\$pkgdir\" cmake --install build")
    
    if(ALPINE_CUSTOM_PACKAGE)
      set(package_content "${package_content}

    # Custom package commands
    ${ALPINE_CUSTOM_PACKAGE}")
    endif()
  else()
    set(package_content "    # Copy pre-built files
    # This requires pre-built binaries to be available
    # Customize this section based on your binary distribution")
  endif()
  list(APPEND platform_vars "ALPINE_PACKAGE_CONTENT=${package_content}")
  
  # Build complete substitution map
  _build_substitution_map(substitutions "${metadata}" "${platform_vars}" "")
  
  # Process template
  _process_template_file("alpine/APKBUILD.in" "${filename}" "${substitutions}")
  
  message(STATUS "Created APKBUILD template: ${filename}")
endfunction()

# ~~~
# Platform configuration for Alpine Linux
# ~~~
function(_get_alpine_platform_config output_var)
  set(config
    "NAME" "alpine"
    "DISPLAY_NAME" "Alpine Linux"
    "TEMPLATE_DIR" "alpine"
    "PACKAGE_FILE" "APKBUILD"
    "HELPER_SCRIPTS" "build.sh;clean.sh;install.sh"
    "DEFAULT_ARCH" "all"
    "DEPENDS_FORMAT" "quoted"
    "FILE_EXTENSIONS" ".apk"
  )
  set(${output_var} "${config}" PARENT_SCOPE)
endfunction()