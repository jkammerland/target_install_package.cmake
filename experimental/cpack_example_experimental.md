```cmake
cmake_minimum_required(VERSION 3.23)
project(MySDK VERSION 1.0.0)

# Include your packaging functions
include(target_install_package.cmake)

# Example: SDK with multiple components
# - Core library (always needed)
# - GUI library (optional)
# - Tools executable (optional)

# Core library - goes into base Runtime/Development
add_library(mycore src/core.cpp)
target_include_directories(mycore PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
target_sources(mycore 
  PUBLIC FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/mycore.h)

# GUI library - goes into base + "GUI" component
add_library(mygui src/gui.cpp)
target_link_libraries(mygui PUBLIC mycore)
target_sources(mygui 
  PUBLIC FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/mygui.h)

# Tools - goes into base + "Tools" component  
add_executable(mytool src/tool.cpp)
target_link_libraries(mytool PRIVATE mycore)

# Prepare installations
target_prepare_package(mycore
  EXPORT_NAME MySDK
  NAMESPACE MySDK::
  VERSION ${PROJECT_VERSION}
  # No COMPONENT specified - only goes to base components
)

target_prepare_package(mygui
  EXPORT_NAME MySDK
  NAMESPACE MySDK::
  COMPONENT GUI  # Goes to Runtime, Development, AND GUI
)

target_prepare_package(mytool
  EXPORT_NAME MySDK
  NAMESPACE MySDK::
  COMPONENT Tools  # Goes to Runtime AND Tools
  RUNTIME_COMPONENT Runtime
  DEVELOPMENT_COMPONENT Development  # Executables don't have dev files
)

# Finalize the export
finalize_package(EXPORT_NAME MySDK)

# Configure CPack
set(CPACK_PACKAGE_NAME "MySDK")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "MyCompany")

# Enable component installation
set(CPACK_COMPONENTS_ALL Runtime Development GUI Tools)
set(CPACK_COMPONENTS_GROUPING ONE_PER_GROUP)

# Define component relationships
set(CPACK_COMPONENT_GUI_DEPENDS Runtime Development)
set(CPACK_COMPONENT_TOOLS_DEPENDS Runtime)

# Component descriptions
set(CPACK_COMPONENT_RUNTIME_DESCRIPTION "Runtime libraries required to run applications")
set(CPACK_COMPONENT_DEVELOPMENT_DESCRIPTION "Development headers and import libraries")
set(CPACK_COMPONENT_GUI_DESCRIPTION "Optional GUI components")
set(CPACK_COMPONENT_TOOLS_DESCRIPTION "Optional command-line tools")

# Set default components
set(CPACK_COMPONENTS_DEFAULT Runtime)

# Generator-specific settings
if(WIN32)
  set(CPACK_GENERATOR "ZIP;WIX")
  set(CPACK_WIX_COMPONENT_INSTALL ON)
elseif(APPLE)
  set(CPACK_GENERATOR "TGZ;DragNDrop")
else()
  set(CPACK_GENERATOR "TGZ;DEB;RPM")
  set(CPACK_DEB_COMPONENT_INSTALL ON)
  set(CPACK_RPM_COMPONENT_INSTALL ON)
endif()

include(CPack)

# Usage examples:
# 
# Install everything:
#   cmake --install . --prefix /usr/local
#
# Install only runtime:
#   cmake --install . --prefix /usr/local --component Runtime
#
# Install GUI components (will include Runtime and Development due to dependencies):
#   cmake --install . --prefix /usr/local --component GUI
#
# Create component packages:
#   cpack -G ZIP
#   Creates: MySDK-1.0.0-Runtime.zip, MySDK-1.0.0-Development.zip, etc.
#
# Create single package with selectable components (Windows):
#   cpack -G WIX
#   Creates installer where users can select components
```