#include <hybrid/sdk.hpp>

int main() {
  return hybrid_extension_value() == 42 ? 0 : 1;
}
