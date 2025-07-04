#pragma once

#include <string>
#include <vector>

namespace utils {

class StringUtils {
public:
  static std::string toUpper(const std::string &str);
  static std::string toLower(const std::string &str);
  static std::vector<std::string> split(const std::string &str, char delimiter);
  static std::string join(const std::vector<std::string> &strings,
                          const std::string &separator);
  static bool startsWith(const std::string &str, const std::string &prefix);
  static bool endsWith(const std::string &str, const std::string &suffix);
};

} // namespace utils