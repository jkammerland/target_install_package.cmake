#pragma once

namespace rpath_example {
    /**
     * Library with NO_DEFAULT_RPATH specified.
     * This library will not have automatic RPATH configuration.
     */
    class DisabledLib {
    public:
        static const char* get_info();
        static bool test_functionality();
    };
}