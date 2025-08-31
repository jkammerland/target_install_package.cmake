#pragma once

#include <string>

namespace myapp {

/**
 * Core functionality for MyApp Export Container Example
 */
class Core {
public:
    Core();
    
    /**
     * Get welcome message for the application
     */
    std::string getWelcomeMessage() const;
    
    /**
     * Process a request and return response
     */
    std::string processRequest(const std::string& request) const;
    
    /**
     * Check if the application is healthy
     */
    bool isHealthy() const;
};

/**
 * Get the application version
 */
std::string getVersion();

}