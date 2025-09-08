#include <exception>
#include <functional>
#include <iostream>
#include <string>

// Core dependency - always available
#include <mylib/dummy.h>

// Data and utility libraries
#include <cbor_tags/tags.h>
#include <data/core.h>
#include <data/utils.h>
#include <json_parser/parser.h>

// Conditional module import - MUST be at file scope
#if defined(HAVE_MATH_PARTITIONS) && defined(MODULES_AVAILABLE)
import math;
#define MATH_MODULES_AVAILABLE 1
#endif

// Test function declarations
bool test_core_libraries();
bool test_data_libraries();
bool test_platform_detection();
bool test_compiler_features();

#ifdef MATH_MODULES_AVAILABLE
bool test_math_modules();
#endif

// Test implementations
bool test_core_libraries() {
  try {
    std::cout << "Testing core libraries...\n";

    // Actually call the function to verify linking works
    mylib::dummy_function(); // Will fail at compile/link time if missing
    std::cout << "  ✓ MyLib core functionality verified\n";

    return true;
  } catch (const std::exception &e) {
    std::cout << "  ✗ Core libraries test failed: " << e.what() << "\n";
    return false;
  }
}

bool test_data_libraries() {
  try {
    std::cout << "Testing data processing libraries...\n";

    // Test actual cbor::tags functionality - will fail if library missing
    bool cbor_valid = cbor::Tags::isValid(cbor::Tags::DATE_TIME);
    if (!cbor_valid) {
      std::cout << "  ✗ CBOR tags validation failed\n";
      return false;
    }
    std::cout << "  ✓ CBOR tags functionality verified\n";

    // Test actual json::parser functionality
    json::Parser json_parser;
    bool json_result = json_parser.parse("{\"test\": true}");
    if (!json_result || !json_parser.isValid()) {
      std::cout << "  ✗ JSON parser functionality failed\n";
      return false;
    }
    std::cout << "  ✓ JSON parser functionality verified\n";

    // Test actual data::core functionality
    data::Core::initialize();
    if (!data::Core::isInitialized()) {
      std::cout << "  ✗ Data core initialization failed\n";
      return false;
    }
    std::cout << "  ✓ Data core functionality verified\n";

    // Test actual data::utils functionality
    auto test_range = data::Utils::range(1, 5);
    int sum = data::Utils::sum(test_range);
    if (sum != 10) { // 1+2+3+4 = 10
      std::cout << "  ✗ Data utils calculation failed\n";
      return false;
    }
    std::cout << "  ✓ Data utils functionality verified\n";

    return true;
  } catch (const std::exception &e) {
    std::cout << "  ✗ Data libraries test failed: " << e.what() << "\n";
    return false;
  }
}

#ifdef MATH_MODULES_AVAILABLE
bool test_math_modules() {
  try {
    std::cout << "Testing C++20 math modules...\n";

    // Test algebra partition - actual function call
    double add_result = algebra::add(10, 5);
    if (add_result != 15.0) {
      std::cout << "  ✗ Algebra partition test failed\n";
      return false;
    }
    std::cout << "  ✓ Algebra partition verified\n";

    // Test geometry partition - actual function call
    double area = geometry::circle_area(2.0);
    if (area <= 0) {
      std::cout << "  ✗ Geometry partition test failed\n";
      return false;
    }
    std::cout << "  ✓ Geometry partition verified\n";

    // Test calculus partition - actual function call
    // Explicitly wrap lambda to avoid module name collision with std::function
    auto square_func = [](double x) { return x * x; };
    std::function<double(double)> square_func_wrapped = square_func;
    double derivative_result = calculus::derivative(square_func_wrapped, 3.0);
    // Should be approximately 6.0 for derivative of x^2 at x=3
    if (derivative_result < 5.9 || derivative_result > 6.1) {
      std::cout << "  ✗ Calculus partition test failed (got "
                << derivative_result << ")\n";
      return false;
    }
    std::cout << "  ✓ Calculus partition verified\n";

    // Test cross-partition functionality - actual function call
    double sphere_vol = calculate_sphere_volume(3.0);
    if (sphere_vol <= 0) {
      std::cout << "  ✗ Cross-partition functionality failed\n";
      return false;
    }
    std::cout << "  ✓ Cross-partition functionality verified\n";

    return true;
  } catch (const std::exception &e) {
    std::cout << "  ✗ Math modules test failed: " << e.what() << "\n";
    return false;
  }
}
#endif

bool test_platform_detection() {
  std::cout << "Testing platform detection...\n";
  std::cout << "  Platform: ";
#ifdef _WIN32
  std::cout << "Windows\n";
#elif defined(__APPLE__)
  std::cout << "macOS\n";
#elif defined(__linux__)
  std::cout << "Linux\n";
#else
  std::cout << "Other\n";
#endif
  std::cout << "  ✓ Platform detection working\n";
  return true;
}

bool test_compiler_features() {
  std::cout << "Testing compiler features...\n";

  std::cout << "  C++20: ";
#if __cplusplus >= 202002L
  std::cout << "Available\n";
#else
  std::cout << "Not available\n";
#endif

  std::cout << "  Modules: ";
#ifdef __cpp_modules
  std::cout << "Supported\n";
#else
  std::cout << "Not supported\n";
#endif

  std::cout << "  Build mode: ";
#ifdef NDEBUG
  std::cout << "Release\n";
#else
  std::cout << "Debug\n";
#endif

  std::cout << "  ✓ Compiler features detected\n";
  return true;
}

int main() {
  std::cout << "=== Examples Integration Test ===\n";

  try {
    bool all_passed = true;

    // Core tests - fail fast on critical dependencies
    if (!test_core_libraries()) {
      std::cout << "✗ Critical: Core libraries failed - aborting\n";
      return 1;
    }

    // Continue with remaining tests
    all_passed &= test_data_libraries();
    all_passed &= test_platform_detection();
    all_passed &= test_compiler_features();

#ifdef MATH_MODULES_AVAILABLE
    all_passed &= test_math_modules();
    std::cout << "✓ Math modules integration tested\n";
#else
    std::cout
        << "ⓘ Math modules not available (expected on older compilers/CMake)\n";
    std::cout
        << "  Requirements: GCC 14+, Clang 19+, MSVC 19.29+, CMake 3.28+\n";
#endif

    std::cout << "\n=== Test Summary ===\n";
    if (all_passed) {
      std::cout << "✓ All available tests passed successfully!\n";
      return 0;
    } else {
      std::cout << "✗ Some tests failed\n";
      return 1;
    }

  } catch (const std::exception &e) {
    std::cout << "✗ Unhandled exception: " << e.what() << "\n";
    return 1;
  } catch (...) {
    std::cout << "✗ Unknown exception occurred\n";
    return 1;
  }
}