#include "sdk/sdk.hpp"

#include <vector>

int main() {
  const std::vector<int> readings{1, 2, 3};
  const std::vector<int> calibrated = sdk::algorithms::calibrate_readings(readings);

  const bool edition_ok = sdk::runtime::edition() == "sdk";
  const bool size_ok = calibrated.size() == 3;
  const bool values_ok = calibrated[0] == 4 && calibrated[1] == 5 && calibrated[2] == 6;
  const bool score_ok = sdk::algorithms::sdk_score(readings) == 15;

  return edition_ok && size_ok && values_ok && score_ok ? 0 : 1;
}
