#include <answer.hpp>
#include <cstdlib>
#include <cstring>

int main() {
#ifdef TIP_EXPECT_EMULATOR
  if (!std::getenv("TIP_CHECK_EMULATED")) {
    return 2;
  }

  const char* delimiters = std::getenv("TIP_CHECK_DELIMITERS");
  if (!delimiters || std::strcmp(delimiters, "]=]-]==]-]===]") != 0) {
    return 3;
  }
#endif

  return answer() == 42 ? 0 : 1;
}
