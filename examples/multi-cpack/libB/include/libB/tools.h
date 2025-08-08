#pragma once

#include <string>
#include <vector>

namespace libB {

class Tools {
public:
    struct Config {
        std::string name;
        std::string value;
        bool enabled;
    };

    static std::vector<Config> loadConfiguration(const std::string& path);
    static bool saveConfiguration(const std::string& path, const std::vector<Config>& configs);
    static void printDiagnostics();
    static std::string generateReport(const std::vector<std::string>& data);
};

} // namespace libB