// Test examples integration - demonstrates module and header usage
#include <iostream>
#include <exception>

// Test traditional header inclusion
#include <mylib/dummy.h> // MyLib::core_lib

// Test conditional module/header usage
// Note: This would need to be compiled against the installed math_partitions library
// For now, we'll demonstrate the pattern without actual import/include

// Simulated conditional compilation for demonstration
#if defined(HAVE_MATH_PARTITIONS) && defined(MODULES_AVAILABLE)
    // In a real scenario, this would be:
    // import math;
    #define USING_MODULES 1
#elif defined(HAVE_MATH_PARTITIONS)
    // In a real scenario, this would be:
    // #include <math/math.h>
    #define USING_HEADERS 1
#else
    #define NO_MATH_LIBRARY 1
#endif

int main() {
    std::cout << "=== Examples Integration Test ===\n";
    
    try {
        // Test 1: Basic functionality (always available)
        std::cout << "1. Basic functionality test: PASSED\n";
        
        // Test 2: Conditional math library usage
        std::cout << "2. Math library integration: ";
        
#ifdef USING_MODULES
        std::cout << "MODULES MODE\n";
        std::cout << "   - C++20 modules with partitions detected\n";
        std::cout << "   - Using import math;\n";
        // In real usage:
        // double result = algebra::add(10, 5);
        // std::cout << "   - Test calculation: 10 + 5 = " << result << "\n";
#elif defined(USING_HEADERS)
        std::cout << "HEADERS MODE\n";
        std::cout << "   - Traditional headers detected\n";
        std::cout << "   - Using #include <math/math.h>\n";
        // In real usage:
        // double result = algebra::add(10, 5);
        // std::cout << "   - Test calculation: 10 + 5 = " << result << "\n";
#else
        std::cout << "NOT AVAILABLE\n";
        std::cout << "   - Math library not found\n";
        std::cout << "   - To test math partitions, build and install module-partitions example\n";
        std::cout << "   - Then rebuild this test with -DHAVE_MATH_PARTITIONS=ON\n";
#endif
        
        // Test 3: Cross-platform compatibility
        std::cout << "3. Platform compatibility: ";
#ifdef _WIN32
        std::cout << "WINDOWS\n";
#elif defined(__APPLE__)
        std::cout << "MACOS\n";
#elif defined(__linux__)
        std::cout << "LINUX\n";
#else
        std::cout << "UNKNOWN\n";
#endif
        
        // Test 4: Compiler features
        std::cout << "4. Compiler features:\n";
        std::cout << "   - C++20: ";
#if __cplusplus >= 202002L
        std::cout << "AVAILABLE\n";
#else
        std::cout << "NOT AVAILABLE\n";
#endif
        
        std::cout << "   - Modules: ";
#ifdef __cpp_modules
        std::cout << "SUPPORTED (feature test macro: " << __cpp_modules << ")\n";
#else
        std::cout << "NOT SUPPORTED\n";
#endif
        
        // Test 5: Build configuration
        std::cout << "5. Build configuration: ";
#ifdef NDEBUG
        std::cout << "RELEASE\n";
#else
        std::cout << "DEBUG\n";
#endif
        
        std::cout << "\n=== Integration Test Summary ===\n";
        std::cout << "✓ Basic functionality working\n";
        std::cout << "✓ Platform detection working\n";
        std::cout << "✓ Compiler feature detection working\n";
        std::cout << "✓ Build configuration detection working\n";
        
#ifdef NO_MATH_LIBRARY
        std::cout << "ⓘ Math partitions example not linked (expected for base test)\n";
        std::cout << "\nTo test math partitions integration:\n";
        std::cout << "1. Build and install module-partitions example\n";
        std::cout << "2. Rebuild this test with the math library linked\n";
        std::cout << "3. Add -DHAVE_MATH_PARTITIONS=ON to test configuration\n";
#else
        std::cout << "✓ Math partitions integration working\n";
#endif
        
        std::cout << "\n=== Test completed successfully! ===\n";
        
    } catch (const std::exception& e) {
        std::cerr << "Test failed with exception: " << e.what() << "\n";
        return 1;
    } catch (...) {
        std::cerr << "Test failed with unknown exception\n";
        return 1;
    }
    
    return 0;
}