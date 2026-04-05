#include "sdk/open_algorithms.hpp"

#include "sdk/runtime.hpp"

#include <numeric>

namespace sdk::algorithms {

std::vector<int> calibrate_readings(const std::vector<int> &raw_readings) {
  std::vector<int> calibrated;
  calibrated.reserve(raw_readings.size());

  for (const int reading : raw_readings) {
    calibrated.push_back(runtime::normalize_reading(reading));
  }

  return calibrated;
}

int sdk_score(const std::vector<int> &raw_readings) {
  const std::vector<int> calibrated = calibrate_readings(raw_readings);
  return std::accumulate(calibrated.begin(), calibrated.end(), 0);
}

} // namespace sdk::algorithms
