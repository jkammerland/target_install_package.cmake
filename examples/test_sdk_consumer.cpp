#include <sdk/sdk.hpp>

#include <vector>

int main() {
  const std::vector<int> values{1, 2, 3};
  const auto calibrated = sdk::algorithms::calibrate(values);

  const bool edition_ok = sdk::runtime::edition() == "prebuilt-sdk";
  const bool values_ok = calibrated.size() == 3 && calibrated[0] == 5 && calibrated[1] == 6 && calibrated[2] == 7;
  const bool score_ok = sdk::algorithms::score(values) == 18;

  return edition_ok && values_ok && score_ok ? 0 : 1;
}
