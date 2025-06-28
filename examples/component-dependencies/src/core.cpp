#include "game_engine/core.h"
#include <iostream>

namespace GameEngine {

void Core::initialize() {
    if (!m_initialized) {
        std::cout << "[Core] Initializing game engine...\n";
        m_initialized = true;
    }
}

void Core::shutdown() {
    if (m_initialized) {
        std::cout << "[Core] Shutting down game engine...\n";
        m_initialized = false;
    }
}

void Core::update(float deltaTime) {
    if (m_initialized) {
        // Core update logic here
        static float totalTime = 0.0f;
        totalTime += deltaTime;
        if (static_cast<int>(totalTime) % 5 == 0) {
            std::cout << "[Core] Engine running for " << totalTime << " seconds\n";
        }
    }
}

bool Core::isInitialized() const {
    return m_initialized;
}

} // namespace GameEngine