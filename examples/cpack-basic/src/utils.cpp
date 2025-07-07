#include "cpack_lib/utils.h"
#include <algorithm>
#include <cctype>
#include <sstream>

namespace mylib {

std::string Utils::join(const std::vector<std::string> &parts,
                        const std::string &delimiter) {
  if (parts.empty()) {
    return "";
  }

  std::ostringstream result;
  result << parts[0];
  for (size_t i = 1; i < parts.size(); ++i) {
    result << delimiter << parts[i];
  }
  return result.str();
}

std::vector<std::string> Utils::split(const std::string &text,
                                      const std::string &delimiter) {
  std::vector<std::string> result;
  size_t start = 0;
  size_t pos = text.find(delimiter);

  while (pos != std::string::npos) {
    result.push_back(text.substr(start, pos - start));
    start = pos + delimiter.length();
    pos = text.find(delimiter, start);
  }
  result.push_back(text.substr(start));

  return result;
}

std::string Utils::trim(const std::string &text) {
  auto start = text.begin();
  auto end = text.end();

  // Trim from start
  start = std::find_if(start, end,
                       [](unsigned char ch) { return !std::isspace(ch); });

  // Trim from end
  end = std::find_if(text.rbegin(), text.rend(), [](unsigned char ch) {
          return !std::isspace(ch);
        }).base();

  return (start < end) ? std::string(start, end) : std::string();
}

} // namespace mylib