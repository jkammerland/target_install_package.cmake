#include "mylib/mylib.h"

namespace mylib {

// Return magic number for testing library functionality
int get_magic_number() {
    return 42;
}

// Return library message for testing library functionality
const char* get_library_message() {
    return "Hello from shared library!";
}

} // namespace mylib