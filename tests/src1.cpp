#include "tests/header.h"

#if STATIC
int foo_static() { return 42; }
#endif
#ifdef SHARED
int foo_shared() { return 13; }
#endif