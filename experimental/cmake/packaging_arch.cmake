# Arch Linux specific packaging functions

include(${CMAKE_CURRENT_LIST_DIR}/packaging_utils.cmake)

# ~~~
# Generate Arch Linux packaging templates
#
# This is the main entry point for Arch Linux packaging generation.
# ~~~
function(generate_arch_packaging_templates output_dir components source_packages binary_packages)
  message(STATUS "Generating Arch Linux templates...")
  
  # Create arch-specific directory
  set(arch_dir "${output_dir}/arch")
  file(MAKE_DIRECTORY "${arch_dir}")
  
  # Get universal and arch-specific metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")
  get_property(arch_config GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_ARCH_CONFIG")
  
  # Create PKGBUILD template
  if(source_packages)
    _create_arch_pkgbuild("${arch_dir}" "${components}" "${metadata}" "${arch_config}" FALSE)
  endif()
  
  if(binary_packages)
    _create_arch_pkgbuild("${arch_dir}" "${components}" "${metadata}" "${arch_config}" TRUE)
  endif()
  
  # Create helper scripts
  _create_platform_helper_scripts("arch" "${arch_dir}")
endfunction()

# ~~~
# Create PKGBUILD template for Arch Linux
# ~~~
function(_create_arch_pkgbuild output_dir components metadata arch_config is_binary)
  # Parse metadata into variables
  _parse_key_value_list(metadata "")
  
  # Parse arch config into ARCH_ prefixed variables
  _parse_key_value_list(arch_config "ARCH_")
  
  # Set defaults
  if(NOT ARCH_ARCH)
    set(ARCH_ARCH "any")
  endif()
  
  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/PKGBUILD-binary")
  else()
    set(filename "${output_dir}/PKGBUILD")
  endif()
  
  # Build platform-specific variables
  set(platform_vars)
  
  # Architecture
  list(APPEND platform_vars "ARCH_ARCH=${ARCH_ARCH}")
  
  # Dependencies
  _format_dependency_line(ARCH_DEPENDS "depends=(" ")" "" depends_line)
  list(APPEND platform_vars "ARCH_DEPENDS_LINE=${depends_line}")
  
  _format_dependency_line(ARCH_MAKEDEPENDS "makedepends=(" ")" "" makedepends_line)
  list(APPEND platform_vars "ARCH_MAKEDEPENDS_LINE=${makedepends_line}")
  
  _format_dependency_line(ARCH_OPTDEPENDS "optdepends=(" ")" "" optdepends_line)
  list(APPEND platform_vars "ARCH_OPTDEPENDS_LINE=${optdepends_line}")
  
  # Source section
  if(NOT is_binary AND SOURCE_URL)
    set(source_section "source=(\"${SOURCE_URL}\")
sha256sums=('SKIP')  # Replace with actual checksum")
  else()
    set(source_section "")
  endif()
  list(APPEND platform_vars "ARCH_SOURCE_SECTION=${source_section}")
  
  # Build function
  if(NOT is_binary)
    set(build_function "build() {
    cd \"${SOURCE_DIR}\"

    # Default CMake build
    cmake -B build \\
        -DCMAKE_BUILD_TYPE=Release \\
        -DCMAKE_INSTALL_PREFIX=/usr \\
        -DCMAKE_INSTALL_LIBDIR=lib")
    
    if(ARCH_CUSTOM_BUILD)
      set(build_function "${build_function}

    # Custom build commands
    ${ARCH_CUSTOM_BUILD}")
    endif()
    
    set(build_function "${build_function}

    cmake --build build
}")
  else()
    set(build_function "")
  endif()
  list(APPEND platform_vars "ARCH_BUILD_FUNCTION=${build_function}")
  
  # Package function content
  if(NOT is_binary)
    set(package_content "    cd \"${SOURCE_DIR}\"

    # Install using CMake
    DESTDIR=\"\$pkgdir\" cmake --install build")
    
    if(ARCH_CUSTOM_PACKAGE)
      set(package_content "${package_content}

    # Custom package commands
    ${ARCH_CUSTOM_PACKAGE}")
    endif()
  else()
    set(package_content "    # Copy pre-built files
    # This requires pre-built binaries to be available
    # Customize this section based on your binary distribution")
  endif()
  list(APPEND platform_vars "ARCH_PACKAGE_CONTENT=${package_content}")
  
  # Build complete substitution map
  _build_substitution_map(substitutions "${metadata}" "${platform_vars}" "")
  
  # Process template
  _process_template_file("arch/PKGBUILD.in" "${filename}" "${substitutions}")
  
  message(STATUS "Created PKGBUILD template: ${filename}")
endfunction()

# ~~~
# Platform configuration for Arch Linux
# ~~~
function(_get_arch_platform_config output_var)
  set(config
    "NAME" "arch"
    "DISPLAY_NAME" "Arch Linux"
    "TEMPLATE_DIR" "arch"
    "PACKAGE_FILE" "PKGBUILD"
    "HELPER_SCRIPTS" "build.sh;clean.sh;install.sh"
    "DEFAULT_ARCH" "any"
    "DEPENDS_FORMAT" "array"
    "FILE_EXTENSIONS" ".pkg.tar.xz"
  )
  set(${output_var} "${config}" PARENT_SCOPE)
endfunction()