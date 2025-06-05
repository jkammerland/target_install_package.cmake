#pragma once

#include <string>
#include <unordered_map>

namespace core {

class Config {
public:
    static void loadFromFile(const std::string& filename);
    static void setValue(const std::string& key, const std::string& value);
    static std::string getValue(const std::string& key, const std::string& defaultValue = "");
    static bool getBool(const std::string& key, bool defaultValue = false);
    static int getInt(const std::string& key, int defaultValue = 0);

private:
    static std::unordered_map<std::string, std::string> values;
};

} // namespace core