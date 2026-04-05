#pragma once

#include <string_view>

namespace sdk::runtime {

std::string_view edition();
int calibration_bias();
int normalize_reading(int reading);

} // namespace sdk::runtime
