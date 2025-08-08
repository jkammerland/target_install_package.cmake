#include "data/core.h"

namespace data {

bool Core::initialized = false;

void Core::initialize() {
    initialized = true;
}

void Core::shutdown() {
    initialized = false;
}

bool Core::isInitialized() {
    return initialized;
}

} // namespace data