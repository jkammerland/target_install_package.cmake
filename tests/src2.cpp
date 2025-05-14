#include "internal.h"
#include "static2/header.h"
#include "static2/version.h"

std::string get_string() {
  return std::string("Hello from static2") + version::VERSION_STRING;
}