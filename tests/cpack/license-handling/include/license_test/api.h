#pragma once

#include "mit_dep.h"
#include "apache_dep.h" 
#include "bsd_dep.h"

namespace license_test {

/// Main API that uses multiple dependencies with different licenses
class API {
public:
    /// Initialize all dependencies
    static bool initialize();
    
    /// Shutdown and cleanup
    static void shutdown();
    
    /// Get version information
    static const char* version();
    
    /// Use MIT-licensed functionality
    static int use_mit_feature(int input);
    
    /// Use Apache-licensed functionality
    static void use_apache_feature(const char* data);
    
    /// Use BSD-licensed functionality
    static double use_bsd_feature(double value);
    
    /// Get license information for all dependencies
    static const char* get_license_info();
};

} // namespace license_test