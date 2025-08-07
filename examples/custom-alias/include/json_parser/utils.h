#pragma once
#include <string>

namespace json {

class Utils {
public:
    static std::string escape(const std::string& str);
    static std::string unescape(const std::string& str);
};

} // namespace json