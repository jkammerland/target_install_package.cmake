#include "source_sdk/algorithms.hpp"
#include "source_sdk/runtime.hpp"

#include <numeric>

namespace source_sdk::algorithms {

namespace support {
int score_offset();
}

std::vector<int> calibrate(std::vector<int> values) {
  for(int &value : values) {
    value += runtime::calibration_bias();
  }
  return values;
}

int score(const std::vector<int> &values) {
  const std::vector<int> calibrated = calibrate(values);
  return std::accumulate(calibrated.begin(), calibrated.end(), 0) + support::score_offset();
}

} // namespace source_sdk::algorithms
