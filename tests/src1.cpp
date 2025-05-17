#include "tests/header.h"
#if STATIC
#include "fmt/format.h"
int foo_static() {
  fmt::print("foo_static fmt\n");
  return 42;
}
#endif
#ifdef SHARED
int foo_shared() { return 13; }
#endif