#pragma once

#include "engine.h"

namespace engine {

// High-level API for easy engine usage
class API {
public:
  static bool initializeEngine(const std::string &configFile = "engine.conf");
  static void runEngine();
  static void shutdownEngine();

  static GameEngine &getEngine();

private:
  static GameEngine *instance;
};

} // namespace engine