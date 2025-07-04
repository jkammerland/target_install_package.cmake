#pragma once

#include <string>

namespace engine {

class GameEngine {
public:
  GameEngine();
  ~GameEngine();

  bool initialize(const std::string &configFile);
  void run();
  void shutdown();

  bool isRunning() const;
  void setTargetFPS(int fps);
  int getTargetFPS() const;

private:
  bool running;
  int targetFPS;
  void update();
  void render();
};

} // namespace engine