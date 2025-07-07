#include "separation_test/core.h"
#include "separation_test/utils.h"
#include <iostream>
#include <cstring>

namespace separation_test {
namespace core {

static bool system_ready = false;

bool Core::init() {
    std::cout << "Initializing core systems..." << std::endl;
    system_ready = true;
    return true;
}

void Core::process(const char* data) {
    if (!system_ready) {
        std::cerr << "Core not initialized!" << std::endl;
        return;
    }
    
    if (utils::Utils::validate_input(data)) {
        std::cout << "Processing: " << data << std::endl;
    } else {
        std::cerr << "Invalid input data" << std::endl;
    }
}

bool Core::is_ready() {
    return system_ready;
}

} // namespace core

namespace utils {

char* Utils::int_to_string(int value) {
    // Simple implementation for testing
    static char buffer[32];
    snprintf(buffer, sizeof(buffer), "%d", value);
    return buffer;
}

unsigned long Utils::hash_string(const char* str) {
    unsigned long hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash;
}

bool Utils::validate_input(const char* input) {
    return input != nullptr && strlen(input) > 0;
}

} // namespace utils
} // namespace separation_test