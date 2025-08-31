#include <iostream>
#include <string>
#include <cstdlib>
#include "intapp/library.h"

int main(int argc, char* argv[]) {
    std::cout << "Integrated Example App v" << intapp::getVersion() << std::endl;
    
    if (argc > 1) {
        std::string arg = argv[1];
        if (arg == "--version" || arg == "-v") {
            std::cout << "Version: " << intapp::getVersion() << std::endl;
            std::cout << "Build: Integrated CPack + Container Example" << std::endl;
            return 0;
        } else if (arg == "--help" || arg == "-h") {
            std::cout << "Usage: " << argv[0] << " [options]" << std::endl;
            std::cout << "Options:" << std::endl;
            std::cout << "  --version, -v    Show version information" << std::endl;
            std::cout << "  --help, -h       Show this help message" << std::endl;
            std::cout << "  --serve          Start server mode" << std::endl;
            return 0;
        } else if (arg == "--serve") {
            std::cout << "Starting server mode..." << std::endl;
            std::cout << intapp::getWelcomeMessage() << std::endl;
            
            // Check environment
            const char* app_env = std::getenv("APP_ENV");
            if (app_env) {
                std::cout << "Environment: " << app_env << std::endl;
            }
            
            // Simulate server
            std::cout << "Server running on port 8080. Press Enter to stop." << std::endl;
            std::string input;
            std::getline(std::cin, input);
            std::cout << "Server stopped." << std::endl;
            return 0;
        }
    }
    
    // Default behavior
    std::cout << intapp::getWelcomeMessage() << std::endl;
    std::cout << "This example demonstrates integrated CPack + Container workflows." << std::endl;
    std::cout << "Run with --help for options." << std::endl;
    
    return 0;
}