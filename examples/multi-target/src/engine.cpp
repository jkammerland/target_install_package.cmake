#include "engine/engine.h"
#include "engine/api.h"
#include "core/logging.h"
#include "core/config.h"
#include "math/operations.h"
#include <thread>
#include <chrono>

namespace engine {

GameEngine* API::instance = nullptr;

GameEngine::GameEngine() : running(false), targetFPS(60) {}

GameEngine::~GameEngine() {
    if (running) {
        shutdown();
    }
}

bool GameEngine::initialize(const std::string& configFile) {
    core::Logger::info("Initializing GameEngine...");
    
    // Load configuration
    core::Config::loadFromFile(configFile);
    
    // Set FPS from config
    targetFPS = core::Config::getInt("target_fps", 60);
    
    core::Logger::info("GameEngine initialized successfully");
    return true;
}

void GameEngine::run() {
    running = true;
    core::Logger::info("Starting game loop");
    
    auto frameTime = std::chrono::milliseconds(1000 / targetFPS);
    
    while (running) {
        auto start = std::chrono::steady_clock::now();
        
        update();
        render();
        
        auto end = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        
        if (elapsed < frameTime) {
            std::this_thread::sleep_for(frameTime - elapsed);
        }
    }
}

void GameEngine::shutdown() {
    core::Logger::info("Shutting down GameEngine");
    running = false;
}

bool GameEngine::isRunning() const {
    return running;
}

void GameEngine::setTargetFPS(int fps) {
    targetFPS = fps;
}

int GameEngine::getTargetFPS() const {
    return targetFPS;
}

void GameEngine::update() {
    // Game logic updates here
}

void GameEngine::render() {
    // Rendering code here
}

// API implementation
bool API::initializeEngine(const std::string& configFile) {
    if (!instance) {
        instance = new GameEngine();
        return instance->initialize(configFile);
    }
    return true;
}

void API::runEngine() {
    if (instance) {
        instance->run();
    }
}

void API::shutdownEngine() {
    if (instance) {
        instance->shutdown();
        delete instance;
        instance = nullptr;
    }
}

GameEngine& API::getEngine() {
    if (!instance) {
        instance = new GameEngine();
    }
    return *instance;
}

} // namespace engine