#include <iostream>
#include <string>
#include <cstdlib>
#include "myapp/core.h"

int main(int argc, char* argv[]) {
    std::cout << "MyApp Export Container Example v" << myapp::getVersion() << std::endl;
    
    // Parse command line arguments
    std::string command = "serve";
    if (argc > 1) {
        command = argv[1];
    }
    
    myapp::Core core;
    
    if (command == "serve" || command == "--serve") {
        // Get port from environment or default
        std::string port = "8080";
        const char* env_port = std::getenv("PORT");
        if (env_port) {
            port = env_port;
        }
        
        std::cout << "Starting MyApp server on port " << port << std::endl;
        std::cout << core.getWelcomeMessage() << std::endl;
        
        // Simulate server - in real app this would be an actual server loop
        std::cout << "Server is running... (Press Enter to stop)" << std::endl;
        std::string input;
        std::getline(std::cin, input);
        
        std::cout << "Server shutting down" << std::endl;
        
    } else if (command == "version" || command == "--version") {
        std::cout << "Version: " << myapp::getVersion() << std::endl;
        std::cout << "Build: Export Container Example" << std::endl;
        
    } else if (command == "help" || command == "--help") {
        std::cout << "Usage: " << argv[0] << " [COMMAND]" << std::endl;
        std::cout << "" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  serve     Start the application server (default)" << std::endl;
        std::cout << "  version   Show version information" << std::endl;
        std::cout << "  help      Show this help message" << std::endl;
        std::cout << "" << std::endl;
        std::cout << "Environment Variables:" << std::endl;
        std::cout << "  PORT      Port to listen on (default: 8080)" << std::endl;
        
    } else {
        std::cout << "Unknown command: " << command << std::endl;
        std::cout << "Try '" << argv[0] << " help' for more information." << std::endl;
        return 1;
    }
    
    return 0;
}