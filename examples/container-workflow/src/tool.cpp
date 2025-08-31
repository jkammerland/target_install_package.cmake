#include <iostream>
#include <string>
#include "webapp/core.h"

int main(int argc, char* argv[]) {
    std::cout << "WebApp Admin Tool v" << webapp::getVersion() << std::endl;
    
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <command>" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  status   - Check webapp status" << std::endl;
        std::cout << "  version  - Show version info" << std::endl;
        std::cout << "  config   - Show configuration" << std::endl;
        return 1;
    }
    
    std::string command = argv[1];
    webapp::Core core;
    
    if (command == "status") {
        std::cout << "WebApp Status: Ready" << std::endl;
        std::cout << core.getWelcomeMessage() << std::endl;
    } else if (command == "version") {
        std::cout << "Version: " << webapp::getVersion() << std::endl;
        std::cout << "Build: Container Workflow Example" << std::endl;
    } else if (command == "config") {
        std::cout << "Configuration:" << std::endl;
        std::cout << "  Install Prefix: /usr/local" << std::endl;
        std::cout << "  Library Path: /usr/local/lib" << std::endl;
        std::cout << "  Binary Path: /usr/local/bin" << std::endl;
    } else {
        std::cout << "Unknown command: " << command << std::endl;
        return 1;
    }
    
    return 0;
}