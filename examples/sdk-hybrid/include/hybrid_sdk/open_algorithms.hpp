#pragma once

#include <vector>

namespace hybrid_sdk::algorithms {

std::vector<int> calibrate_readings(const std::vector<int> &raw_readings);
int sdk_score(const std::vector<int> &raw_readings);

} // namespace hybrid_sdk::algorithms
