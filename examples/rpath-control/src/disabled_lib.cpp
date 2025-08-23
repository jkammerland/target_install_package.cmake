#include "rpath_example/disabled_lib.h"

namespace rpath_example {
    const char* DisabledLib::get_info() {
        return "DisabledLib: NO_DEFAULT_RPATH specified - no automatic RPATH";
    }
    
    bool DisabledLib::test_functionality() {
        // Simple functionality test
        return true;
    }
}