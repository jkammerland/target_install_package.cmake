#include "tests/header.h"
#include <cassert>
int main() {
  assert(foo_static() == 42);
  assert(foo_shared() == 13);
  assert(foo_interface() == 1337);
  assert(foo_interface() + foo_static() + foo_shared() == 1392);
  return 0;
}