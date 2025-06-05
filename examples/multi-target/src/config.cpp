#include "core/config.h"
#include <fstream>
#include <sstream>

namespace core {

std::unordered_map<std::string, std::string> Config::values;

void Config::loadFromFile(const std::string& filename) {
    std::ifstream file(filename);
    std::string line;
    
    while (std::getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        
        size_t pos = line.find('=');
        if (pos != std::string::npos) {
            std::string key = line.substr(0, pos);
            std::string value = line.substr(pos + 1);
            values[key] = value;
        }
    }
}

void Config::setValue(const std::string& key, const std::string& value) {
    values[key] = value;
}

std::string Config::getValue(const std::string& key, const std::string& defaultValue) {
    auto it = values.find(key);
    return (it != values.end()) ? it->second : defaultValue;
}

bool Config::getBool(const std::string& key, bool defaultValue) {
    std::string value = getValue(key);
    if (value.empty()) return defaultValue;
    return value == "true" || value == "1" || value == "yes";
}

int Config::getInt(const std::string& key, int defaultValue) {
    std::string value = getValue(key);
    if (value.empty()) return defaultValue;
    return std::stoi(value);
}

} // namespace core