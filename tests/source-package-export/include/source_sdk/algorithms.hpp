#pragma once

#include <vector>

namespace source_sdk::algorithms {

std::vector<int> calibrate(std::vector<int> values);
int score(const std::vector<int>& values);

} // namespace source_sdk::algorithms
