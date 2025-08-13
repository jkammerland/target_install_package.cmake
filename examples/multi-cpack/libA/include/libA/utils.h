#pragma once

#include <string>
#include <vector>

namespace libA {

class Utils {
public:
    static std::string join(const std::vector<std::string>& parts, const std::string& delimiter);
    static std::vector<std::string> split(const std::string& str, const std::string& delimiter);
    static std::string toUpper(const std::string& str);
    static std::string toLower(const std::string& str);
};

} // namespace libA