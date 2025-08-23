#include "rpath_example/user_lib.h"

namespace rpath_example {
    const char* UserLib::get_info() {
        return "UserLib: Custom user-configured RPATH preserved";
    }
    
    bool UserLib::test_functionality() {
        // Simple functionality test
        return true;
    }
}