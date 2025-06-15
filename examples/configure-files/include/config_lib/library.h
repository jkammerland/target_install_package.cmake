#pragma once

#include <string>

namespace config {

class Library {
public:
  static std::string getName();
  static std::string getVersion();
  static std::string getDescription();
  static std::string getAuthor();

  static void initialize();
  static void cleanup();

  static bool isLoggingEnabled();
  static int getMaxBufferSize();

private:
  static bool initialized;
};

} // namespace config