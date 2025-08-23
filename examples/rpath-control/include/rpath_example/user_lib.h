#pragma once

namespace rpath_example {
    /**
     * Library with user-configured RPATH.
     * This library has custom RPATH set by user, which should be preserved.
     */
    class UserLib {
    public:
        static const char* get_info();
        static bool test_functionality();
    };
}