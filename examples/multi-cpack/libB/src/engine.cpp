#include "libB/engine.h"
#include "libA/core.h"
#include "libA/utils.h"
#include <iostream>

namespace libB {

Engine::Engine() : coreSystem_(std::make_unique<libA::Core>()), running_(false) {
}

Engine::~Engine() {
    if (running_) {
        stop();
    }
}

bool Engine::start() {
    if (running_) {
        return false;
    }
    
    int result = coreSystem_->initialize();
    if (result != 0) {
        std::cerr << "Failed to initialize core system\n";
        return false;
    }
    
    running_ = true;
    std::cout << "Engine started successfully\n";
    return true;
}

bool Engine::stop() {
    if (!running_) {
        return false;
    }
    
    coreSystem_->shutdown();
    running_ = false;
    std::cout << "Engine stopped\n";
    return true;
}

bool Engine::isRunning() const {
    return running_;
}

std::string Engine::getStatus() const {
    if (running_) {
        return "Engine running with LibA version: " + coreSystem_->getVersion();
    }
    return "Engine stopped";
}

void Engine::processData(const std::string& data) {
    if (!running_) {
        std::cerr << "Engine not running, cannot process data\n";
        return;
    }
    
    // Use libA utilities for processing
    auto parts = libA::Utils::split(data, ",");
    for (const auto& part : parts) {
        std::cout << "Processing: " << libA::Utils::toUpper(part) << "\n";
    }
}

} // namespace libB