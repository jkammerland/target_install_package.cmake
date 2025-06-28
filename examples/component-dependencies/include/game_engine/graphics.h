#pragma once

namespace GameEngine {

/**
 * Graphics component - requires OpenGL and GLFW when used
 * 
 * Component dependencies:
 * - OpenGL 4.5 REQUIRED
 * - glfw3 3.3 REQUIRED
 */
class Graphics {
public:
    void initializeRenderer();
    void renderFrame();
    void createWindow(int width, int height, const char* title);
    void destroyWindow();
    
    bool isRendererInitialized() const;
    
private:
    bool m_rendererInitialized = false;
    void* m_window = nullptr; // Mock window handle
};

} // namespace GameEngine