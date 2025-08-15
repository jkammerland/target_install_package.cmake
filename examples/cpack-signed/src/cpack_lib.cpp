#include "cpack_lib/core.h"
#include <iostream>

namespace mylib {

bool Core::initialized_ = false;

bool Core::initialize() {
  if (initialized_) {
    return true;
  }

  std::cout << "MyLib Core initializing..." << std::endl;
  initialized_ = true;
  return true;
}

void Core::shutdown() {
  if (!initialized_) {
    return;
  }

  std::cout << "MyLib Core shutting down..." << std::endl;
  initialized_ = false;
}

const char *Core::version() { return "1.2.0"; }

} // namespace mylib