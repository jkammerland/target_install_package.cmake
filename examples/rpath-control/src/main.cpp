#include <iostream>
#include "rpath_example/default_lib.h"
#include "rpath_example/disabled_lib.h"
#include "rpath_example/user_lib.h"

int main() {
    std::cout << "RPATH Control Example\n";
    std::cout << "=====================\n\n";
    
    // Test default library
    std::cout << rpath_example::DefaultLib::get_info() << "\n";
    std::cout << "Functionality test: " << (rpath_example::DefaultLib::test_functionality() ? "PASS" : "FAIL") << "\n\n";
    
    // Test disabled library
    std::cout << rpath_example::DisabledLib::get_info() << "\n";
    std::cout << "Functionality test: " << (rpath_example::DisabledLib::test_functionality() ? "PASS" : "FAIL") << "\n\n";
    
    // Test user library
    std::cout << rpath_example::UserLib::get_info() << "\n";
    std::cout << "Functionality test: " << (rpath_example::UserLib::test_functionality() ? "PASS" : "FAIL") << "\n\n";
    
    std::cout << "All libraries loaded successfully!\n";
    std::cout << "This demonstrates the RPATH control feature working correctly.\n";
    
    return 0;
}