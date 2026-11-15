cmake_minimum_required(VERSION 4.2)

project(
  tip_appimage_example
  VERSION 1.2.3
  DESCRIPTION "AppImage packaging example"
  HOMEPAGE_URL "https://github.com/jkammerland/target_install_package.cmake"
  LANGUAGES CXX)

set(CMAKE_INSTALL_LIBDIR
    lib
    CACHE PATH "Library directory compatible with CPack's AppImage RPATH")
include(GNUInstallDirs)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

set(TIP_APPIMAGE_TOOL_EXECUTABLE
    ""
    CACHE FILEPATH "Optional appimagetool executable override")
set(TIP_APPIMAGE_PATCHELF_EXECUTABLE
    ""
    CACHE FILEPATH "Optional patchelf executable override")
set(TIP_APPIMAGE_RUNTIME_FILE
    ""
    CACHE FILEPATH "Optional pinned AppImage runtime file")
set(TIP_APPIMAGE_PACKAGE_FILE_NAME
    "tip-appimage-example-${PROJECT_VERSION}-${CMAKE_SYSTEM_PROCESSOR}"
    CACHE STRING "Deterministic AppImage artifact basename")

add_library(tip_appimage_greeting SHARED src/greeting.cpp)
target_include_directories(tip_appimage_greeting PRIVATE include)
set_target_properties(tip_appimage_greeting PROPERTIES INSTALL_RPATH "$ORIGIN")

add_executable(tip-appimage src/main.cpp)
target_include_directories(tip-appimage PRIVATE include)
target_link_libraries(tip-appimage PRIVATE tip_appimage_greeting)

install(
  TARGETS tip_appimage_greeting tip-appimage
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Runtime
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development)
install(
  FILES packaging/io.github.target_install_package.appimage.desktop
  DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
  COMPONENT Runtime)
install(
  FILES packaging/tip-appimage.svg
  DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
  COMPONENT Runtime)
install(
  FILES include/tip-appimage/greeting.hpp
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tip-appimage-sdk
  COMPONENT Development)
install(
  FILES docs/runtime-dependencies.txt
  DESTINATION ${CMAKE_INSTALL_DOCDIR}
  COMPONENT Documentation)

set(_tip_appimage_arguments "")
if(TIP_APPIMAGE_TOOL_EXECUTABLE)
  list(APPEND _tip_appimage_arguments APPIMAGE_TOOL_EXECUTABLE "${TIP_APPIMAGE_TOOL_EXECUTABLE}")
endif()
if(TIP_APPIMAGE_PATCHELF_EXECUTABLE)
  list(APPEND _tip_appimage_arguments APPIMAGE_PATCHELF_EXECUTABLE "${TIP_APPIMAGE_PATCHELF_EXECUTABLE}")
endif()

set(_tip_appimage_cpack_vars CPACK_PACKAGE_FILE_NAME "${TIP_APPIMAGE_PACKAGE_FILE_NAME}" CPACK_APPIMAGE_NO_APPSTREAM ON)
if(TIP_APPIMAGE_RUNTIME_FILE)
  list(APPEND _tip_appimage_cpack_vars CPACK_APPIMAGE_RUNTIME_FILE "${TIP_APPIMAGE_RUNTIME_FILE}")
endif()

export_cpack(
  PACKAGE_NAME
  tip-appimage-example
  PACKAGE_VENDOR
  target_install_package.cmake
  PACKAGE_CONTACT
  maintainers@example.invalid
  GENERATORS
  AppImage
  COMPONENTS
  Runtime
  Development
  APPIMAGE_DESKTOP_FILE
  packaging/io.github.target_install_package.appimage.desktop
  APPIMAGE_ICON_FILE
  packaging/tip-appimage.svg
  ${_tip_appimage_arguments}
  ADDITIONAL_CPACK_VARS
  ${_tip_appimage_cpack_vars})
