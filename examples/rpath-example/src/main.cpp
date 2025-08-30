#include <iostream>
#include "mylib/mylib.h"

int main() {
    // Test library functions to verify RPATH functionality
    std::cout << "Testing RPATH example...\n";
    std::cout << "Magic number: " << mylib::get_magic_number() << "\n";
    std::cout << "Library message: " << mylib::get_library_message() << "\n";
    std::cout << "RPATH example completed successfully!\n";
    return 0;
}