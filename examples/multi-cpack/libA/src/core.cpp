#include "libA/core.h"
#include <iostream>

namespace libA {

Core::Core() : initialized_(false) {
}

Core::~Core() {
    if (initialized_) {
        shutdown();
    }
}

std::string Core::getVersion() const {
    return "1.0.0";
}

int Core::initialize() {
    if (initialized_) {
        return 1; // Already initialized
    }
    
    std::cout << "LibA Core initialized\n";
    initialized_ = true;
    return 0;
}

void Core::shutdown() {
    if (initialized_) {
        std::cout << "LibA Core shutdown\n";
        initialized_ = false;
    }
}

} // namespace libA