#include "webapp/core.h"
#include <sstream>

namespace webapp {

Core::Core() {
    // Initialize core functionality
}

std::string Core::getWelcomeMessage() const {
    return "Welcome to WebApp - A container workflow example!";
}

std::string Core::processRequest(const std::string& request) const {
    std::ostringstream response;
    response << "Processed request: " << request;
    return response.str();
}

std::string getVersion() {
    return "1.0.0";
}

}