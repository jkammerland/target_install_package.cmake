#include "hybrid_sdk/sdk.hpp"

#include <vector>

int main() {
  const std::vector<int> readings{1, 2, 3};
  const std::vector<int> calibrated = hybrid_sdk::algorithms::calibrate_readings(readings);

  const bool edition_ok = hybrid_sdk::runtime::edition() == "hybrid-sdk";
  const bool size_ok = calibrated.size() == 3;
  const bool values_ok = calibrated[0] == 4 && calibrated[1] == 5 && calibrated[2] == 6;
  const bool score_ok = hybrid_sdk::algorithms::sdk_score(readings) == 15;

  return edition_ok && size_ok && values_ok && score_ok ? 0 : 1;
}
