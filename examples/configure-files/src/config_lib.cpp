#include "config/build_info.h"
#include "config/internal_config.h"
#include "config/library.h"
#include "config/version.h"
#include <iostream>

namespace config {

bool Library::initialized = false;

std::string Library::getName() { return CONFIG_LIB_NAME; }

std::string Library::getVersion() { return CONFIG_LIB_VERSION_STRING; }

std::string Library::getDescription() { return CONFIG_LIB_DESCRIPTION; }

std::string Library::getAuthor() { return CONFIG_LIB_AUTHOR; }

void Library::initialize() {
  if (initialized)
    return;

  std::cout << "Initializing " << getName() << " v" << getVersion()
            << std::endl;
  std::cout << "Description: " << getDescription() << std::endl;
  std::cout << "Author: " << getAuthor() << std::endl;
  std::cout << "Build system: CMake " << CMAKE_VERSION << std::endl;
  std::cout << "Platform: " << CMAKE_SYSTEM_NAME << std::endl;
  std::cout << "Compiler: " << CMAKE_CXX_COMPILER_ID << std::endl;

#if INTERNAL_LOGGING_ENABLED
  std::cout << "Logging: ENABLED" << std::endl;
#else
  std::cout << "Logging: DISABLED" << std::endl;
#endif

  std::cout << "Max buffer size: " << getMaxBufferSize() << std::endl;
  std::cout << "Internal buffer size: " << INTERNAL_BUFFER_SIZE << std::endl;

  initialized = true;
}

void Library::cleanup() {
  if (!initialized)
    return;

  std::cout << "Cleaning up " << getName() << std::endl;
  initialized = false;
}

bool Library::isLoggingEnabled() {
#ifdef ENABLE_LOGGING
  return true;
#else
  return false;
#endif
}

int Library::getMaxBufferSize() { return MAX_BUFFER_SIZE; }

} // namespace config