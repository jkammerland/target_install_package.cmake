#include "rpath_example/default_lib.h"

namespace rpath_example {
    const char* DefaultLib::get_info() {
        return "DefaultLib: Using automatic RPATH configuration";
    }
    
    bool DefaultLib::test_functionality() {
        // Simple functionality test
        return true;
    }
}