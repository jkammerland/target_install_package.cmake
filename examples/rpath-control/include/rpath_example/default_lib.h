#pragma once

namespace rpath_example {
    /**
     * Library with default RPATH configuration.
     * This library will have RPATH configured automatically based on platform.
     */
    class DefaultLib {
    public:
        static const char* get_info();
        static bool test_functionality();
    };
}