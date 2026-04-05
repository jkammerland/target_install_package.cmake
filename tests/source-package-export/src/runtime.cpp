#include "source_sdk/runtime.hpp"

namespace source_sdk::runtime {

std::string_view edition() {
  return "source-sdk";
}

int calibration_bias() {
  return 4;
}

} // namespace source_sdk::runtime
