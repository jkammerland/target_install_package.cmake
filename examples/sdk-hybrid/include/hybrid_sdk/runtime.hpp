#pragma once

#include <string_view>

namespace hybrid_sdk::runtime {

std::string_view edition();
int calibration_bias();
int normalize_reading(int reading);

} // namespace hybrid_sdk::runtime
