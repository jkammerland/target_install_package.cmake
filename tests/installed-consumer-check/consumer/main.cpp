#include <answer.hpp>
#include <cstdlib>

int main() {
#ifdef TIP_EXPECT_EMULATOR
  if (!std::getenv("TIP_CHECK_EMULATED")) {
    return 2;
  }
#endif

  return answer() == 42 ? 0 : 1;
}
