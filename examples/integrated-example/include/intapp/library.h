#pragma once

#include <string>

namespace intapp {

/**
 * Get the application version
 */
std::string getVersion();

/**
 * Get welcome message
 */
std::string getWelcomeMessage();

/**
 * Process some data (example functionality)
 */
std::string processData(const std::string& input);

}