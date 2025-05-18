#pragma once

#ifdef INTERFACE
inline int foo_interface() { return 1337; }
#endif
#ifdef STATIC
int foo_static();
#endif
#ifdef SHARED
#include <fmt/format.h>
int foo_shared();
#endif