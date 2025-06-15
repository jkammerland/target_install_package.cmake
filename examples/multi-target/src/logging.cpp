#include "core/logging.h"
#include <iostream>

namespace core {

LogLevel Logger::currentLevel = LogLevel::INFO;

void Logger::setLevel(LogLevel level) { currentLevel = level; }

void Logger::debug(const std::string &message) {
  log(LogLevel::DEBUG, message);
}

void Logger::info(const std::string &message) { log(LogLevel::INFO, message); }

void Logger::warning(const std::string &message) {
  log(LogLevel::WARNING, message);
}

void Logger::error(const std::string &message) {
  log(LogLevel::ERROR, message);
}

void Logger::log(LogLevel level, const std::string &message) {
  if (level >= currentLevel) {
    std::cout << "[" << levelToString(level) << "] " << message << std::endl;
  }
}

std::string Logger::levelToString(LogLevel level) {
  switch (level) {
  case LogLevel::DEBUG:
    return "DEBUG";
  case LogLevel::INFO:
    return "INFO";
  case LogLevel::WARNING:
    return "WARNING";
  case LogLevel::ERROR:
    return "ERROR";
  default:
    return "UNKNOWN";
  }
}

} // namespace core