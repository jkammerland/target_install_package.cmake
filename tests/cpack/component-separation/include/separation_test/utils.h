#pragma once

namespace separation_test {
namespace utils {

/// Utility functions
class Utils {
public:
    /// Convert integer to string
    static char* int_to_string(int value);
    
    /// Calculate hash of string
    static unsigned long hash_string(const char* str);
    
    /// Validate input data
    static bool validate_input(const char* input);
};

} // namespace utils
} // namespace separation_test