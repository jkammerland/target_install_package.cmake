#pragma once

#include <vector>

namespace sdk::algorithms {

std::vector<int> calibrate_readings(const std::vector<int> &raw_readings);
int sdk_score(const std::vector<int> &raw_readings);

} // namespace sdk::algorithms
