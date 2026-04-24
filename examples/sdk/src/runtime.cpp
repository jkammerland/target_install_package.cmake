#include <sdk/runtime.hpp>

namespace sdk::runtime {

std::string edition() {
  return "prebuilt-sdk";
}

int calibration_offset() {
  return 4;
}

} // namespace sdk::runtime
