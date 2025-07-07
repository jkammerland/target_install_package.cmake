#pragma once

namespace separation_test {
namespace core {

/// Core functionality for the library
class Core {
public:
    /// Initialize core systems
    static bool init();
    
    /// Process data
    static void process(const char* data);
    
    /// Get system status
    static bool is_ready();
};

} // namespace core
} // namespace separation_test