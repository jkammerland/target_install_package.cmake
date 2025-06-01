#include "tests/header.h"

#if STATIC
#include "fmt/format.h"
#include "tests/internal.h"
int foo_static() {
  fmt::print("foo_static fmt returning 42\n");
  internal_static1_print();
  return 42;
}
#endif
#ifdef SHARED
int foo_shared() {
  fmt::print("foo_shared fmt returning 13\n");
  return 13;
}
#endif