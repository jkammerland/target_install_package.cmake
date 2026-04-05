#pragma once

#include <string_view>

namespace source_sdk::runtime {

std::string_view edition();
int calibration_bias();

} // namespace source_sdk::runtime
