#include "tests/header.h"
int main() {
  if (foo_static() != 42) {
    return 1;
  }
  if (foo_shared() != 13) {
    return 2;
  }
  if (foo_interface() != 1337) {
    return 3;
  }
  if (foo_interface() + foo_static() + foo_shared() != 1392) {
    return 4;
  }
  return 0;
}
