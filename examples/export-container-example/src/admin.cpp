#include <iostream>
#include <string>
#include "myapp/core.h"

int main(int argc, char* argv[]) {
    std::cout << "MyApp Admin Tool v" << myapp::getVersion() << std::endl;
    
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <command>" << std::endl;
        std::cout << "Commands:" << std::endl;
        std::cout << "  status    - Check application status" << std::endl;
        std::cout << "  version   - Show version information" << std::endl;
        std::cout << "  health    - Run health check" << std::endl;
        std::cout << "  config    - Show configuration" << std::endl;
        return 1;
    }
    
    std::string command = argv[1];
    myapp::Core core;
    
    if (command == "status") {
        std::cout << "MyApp Status: Ready" << std::endl;
        std::cout << core.getWelcomeMessage() << std::endl;
        
    } else if (command == "version") {
        std::cout << "Version: " << myapp::getVersion() << std::endl;
        std::cout << "Build: Export Container Admin Tool" << std::endl;
        
    } else if (command == "health") {
        std::cout << "Running health check..." << std::endl;
        bool healthy = core.isHealthy();
        std::cout << "Health Status: " << (healthy ? "OK" : "FAILED") << std::endl;
        return healthy ? 0 : 1;
        
    } else if (command == "config") {
        std::cout << "Configuration:" << std::endl;
        std::cout << "  Install Prefix: /usr/local" << std::endl;
        std::cout << "  Library Path: /usr/local/lib" << std::endl;
        std::cout << "  Binary Path: /usr/local/bin" << std::endl;
        std::cout << "  Config Path: /usr/local/share" << std::endl;
        
    } else {
        std::cout << "Unknown command: " << command << std::endl;
        std::cout << "Try '" << argv[0] << "' without arguments for help." << std::endl;
        return 1;
    }
    
    return 0;
}