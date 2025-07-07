#include "separation_test/api.h"
#include "separation_test/core.h"
#include "separation_test/version.h"
#include <iostream>
#include <cstring>

namespace separation_test {

bool API::initialize() {
    std::cout << "Initializing " << SEPARATION_TEST_VERSION_STRING << std::endl;
    return core::Core::init();
}

void API::shutdown() {
    std::cout << "Shutting down SeparationTest API" << std::endl;
}

const char* API::version() {
    return SEPARATION_TEST_VERSION;
}

int API::test_operation(int input) {
    if (input < 0) {
        return -1;
    }
    return input * 2 + 1;
}

} // namespace separation_test