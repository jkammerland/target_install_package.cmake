#include "hybrid_sdk/runtime.hpp"

namespace hybrid_sdk::runtime {

std::string_view edition() {
  return "hybrid-sdk";
}

int calibration_bias() {
  return 3;
}

int normalize_reading(int reading) {
  return reading + calibration_bias();
}

} // namespace hybrid_sdk::runtime
