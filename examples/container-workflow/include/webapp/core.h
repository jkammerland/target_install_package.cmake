#pragma once

#include <string>

namespace webapp {

/**
 * Core functionality for the WebApp example
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
};

/**
 * Get the application version
 */
std::string getVersion();

}