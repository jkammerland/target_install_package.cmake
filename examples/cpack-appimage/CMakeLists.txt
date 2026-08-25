CMAKE_MINIMUM_REQUIRED(VERSION 4.2)

PROJECT(
  tip_appimage_example
  VERSION 1.2.3
  DESCRIPTION "AppImage packaging example"
  HOMEPAGE_URL "https://github.com/jkammerland/target_install_package.cmake"
  LANGUAGES CXX)

SET(CMAKE_INSTALL_LIBDIR
    lib
    CACHE PATH "Library directory compatible with CPack's AppImage RPATH")
INCLUDE(GNUInstallDirs)
INCLUDE(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

SET(TIP_APPIMAGE_TOOL_EXECUTABLE
    ""
    CACHE FILEPATH "Optional appimagetool executable override")
SET(TIP_APPIMAGE_PATCHELF_EXECUTABLE
    ""
    CACHE FILEPATH "Optional patchelf executable override")
SET(TIP_APPIMAGE_RUNTIME_FILE
    ""
    CACHE FILEPATH "Optional pinned AppImage runtime file")
SET(TIP_APPIMAGE_PACKAGE_FILE_NAME
    "tip-appimage-example-${PROJECT_VERSION}-${CMAKE_SYSTEM_PROCESSOR}"
    CACHE STRING "Deterministic AppImage artifact basename")

ADD_LIBRARY(tip_appimage_greeting SHARED src/greeting.cpp)
TARGET_INCLUDE_DIRECTORIES(tip_appimage_greeting PRIVATE include)
SET_TARGET_PROPERTIES(tip_appimage_greeting PROPERTIES INSTALL_RPATH "$ORIGIN")

ADD_EXECUTABLE(tip-appimage src/main.cpp)
TARGET_INCLUDE_DIRECTORIES(tip-appimage PRIVATE include)
TARGET_LINK_LIBRARIES(tip-appimage PRIVATE tip_appimage_greeting)

INSTALL(
  TARGETS tip_appimage_greeting tip-appimage
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Runtime
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development)
INSTALL(
  FILES packaging/io.github.target_install_package.appimage.desktop
  DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
  COMPONENT Runtime)
INSTALL(
  FILES packaging/tip-appimage.svg
  DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
  COMPONENT Runtime)
INSTALL(
  FILES include/tip-appimage/greeting.hpp
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/tip-appimage-sdk
  COMPONENT Development)
INSTALL(
  FILES docs/runtime-dependencies.txt
  DESTINATION ${CMAKE_INSTALL_DOCDIR}
  COMPONENT Documentation)

SET(_tip_appimage_arguments "")
IF(TIP_APPIMAGE_TOOL_EXECUTABLE)
  LIST(APPEND _tip_appimage_arguments APPIMAGE_TOOL_EXECUTABLE "${TIP_APPIMAGE_TOOL_EXECUTABLE}")
ENDIF()
IF(TIP_APPIMAGE_PATCHELF_EXECUTABLE)
  LIST(APPEND _tip_appimage_arguments APPIMAGE_PATCHELF_EXECUTABLE "${TIP_APPIMAGE_PATCHELF_EXECUTABLE}")
ENDIF()

SET(_tip_appimage_cpack_vars CPACK_PACKAGE_FILE_NAME "${TIP_APPIMAGE_PACKAGE_FILE_NAME}" CPACK_APPIMAGE_NO_APPSTREAM ON)
IF(TIP_APPIMAGE_RUNTIME_FILE)
  LIST(APPEND _tip_appimage_cpack_vars CPACK_APPIMAGE_RUNTIME_FILE "${TIP_APPIMAGE_RUNTIME_FILE}")
ENDIF()

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
