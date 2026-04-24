#include <sdk/algorithms.hpp>

#include <sdk/runtime.hpp>

#include <numeric>

namespace sdk::algorithms {

std::vector<int> calibrate(const std::vector<int> &values) {
  std::vector<int> result;
  result.reserve(values.size());

  const int offset = sdk::runtime::calibration_offset();
  for (int value : values) {
    result.push_back(value + offset);
  }

  return result;
}

int score(const std::vector<int> &values) {
  const auto calibrated = calibrate(values);
  return std::accumulate(calibrated.begin(), calibrated.end(), 0);
}

} // namespace sdk::algorithms
