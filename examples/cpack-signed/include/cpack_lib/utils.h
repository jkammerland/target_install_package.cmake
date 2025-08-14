#pragma once
#include <string>
#include <vector>

namespace mylib {

class Utils {
public:
    static std::string join(const std::vector<std::string>& parts, const std::string& delimiter);
    static std::vector<std::string> split(const std::string& text, const std::string& delimiter);
    static std::string trim(const std::string& text);
};

} // namespace mylib