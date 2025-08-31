#include <iostream>
#include <string>
#include <cstdlib>
#include "webapp/core.h"

int main(int argc, char* argv[]) {
    std::cout << "WebApp Container Example v" << webapp::getVersion() << std::endl;
    
    // Simple HTTP-like server simulation
    std::string port = "8080";
    if (argc > 1) {
        port = argv[1];
    }
    
    // Check for environment variable
    const char* env_port = std::getenv("PORT");
    if (env_port) {
        port = env_port;
    }
    
    webapp::Core core;
    std::cout << "Starting webapp on port " << port << std::endl;
    std::cout << core.getWelcomeMessage() << std::endl;
    
    // Simulate server loop
    std::cout << "Server running... (Press Ctrl+C to stop)" << std::endl;
    
    // In a real app, this would be a server loop
    // For demo, just wait for input
    std::string input;
    std::getline(std::cin, input);
    
    std::cout << "Shutting down webapp" << std::endl;
    return 0;
}