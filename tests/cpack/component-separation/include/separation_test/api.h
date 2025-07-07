#pragma once

namespace separation_test {
    
/// Main API class for component separation testing
class API {
public:
    /// Initialize the API
    static bool initialize();
    
    /// Shutdown the API
    static void shutdown();
    
    /// Get version string
    static const char* version();
    
    /// Perform a test operation
    static int test_operation(int input);
};

} // namespace separation_test