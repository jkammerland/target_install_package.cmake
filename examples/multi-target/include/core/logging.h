#pragma once

#include <string>

namespace core {

enum class LogLevel { DEBUG, INFO, WARNING, ERROR };

class Logger {
public:
  static void setLevel(LogLevel level);
  static void debug(const std::string &message);
  static void info(const std::string &message);
  static void warning(const std::string &message);
  static void error(const std::string &message);

private:
  static LogLevel currentLevel;
  static void log(LogLevel level, const std::string &message);
  static std::string levelToString(LogLevel level);
};

} // namespace core