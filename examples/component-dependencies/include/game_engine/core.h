#pragma once

namespace GameEngine {

/**
 * Core game engine functionality - always available
 */
class Core {
public:
    void initialize();
    void shutdown();
    void update(float deltaTime);
    
    bool isInitialized() const;
    
private:
    bool m_initialized = false;
};

} // namespace GameEngine