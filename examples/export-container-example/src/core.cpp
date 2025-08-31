#include "myapp/core.h"
#include <sstream>

namespace myapp {

Core::Core() {
    // Initialize core functionality
}

std::string Core::getWelcomeMessage() const {
    return "Welcome to MyApp - Export Container Example!";
}

std::string Core::processRequest(const std::string& request) const {
    std::ostringstream response;
    response << "Processed: " << request;
    return response.str();
}

bool Core::isHealthy() const {
    return true;
}

std::string getVersion() {
    return "2.0.0";
}

}