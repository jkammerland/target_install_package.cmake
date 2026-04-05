#include "sdk/runtime.hpp"

namespace sdk::runtime {

std::string_view edition() {
  return "sdk";
}

int calibration_bias() {
  return 3;
}

int normalize_reading(int reading) {
  return reading + calibration_bias();
}

} // namespace sdk::runtime
