#include "separation_test/api.h"
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    std::cout << "SeparationTest Tool v" << separation_test::API::version() << std::endl;
    
    if (!separation_test::API::initialize()) {
        std::cerr << "Failed to initialize SeparationTest" << std::endl;
        return 1;
    }
    
    if (argc > 1) {
        std::string command = argv[1];
        if (command == "--version" || command == "-v") {
            std::cout << "Version: " << separation_test::API::version() << std::endl;
        } else if (command == "--help" || command == "-h") {
            std::cout << "Usage: separation_tool [--version|-v] [--help|-h] [number]" << std::endl;
            std::cout << "  --version, -v  Show version" << std::endl;
            std::cout << "  --help, -h     Show this help" << std::endl;
            std::cout << "  number         Test operation on number" << std::endl;
        } else {
            try {
                int input = std::stoi(command);
                int result = separation_test::API::test_operation(input);
                std::cout << "Result: " << result << std::endl;
            } catch (...) {
                std::cout << "Processing: " << command << std::endl;
            }
        }
    } else {
        std::cout << "SeparationTest tool ready. Use --help for usage." << std::endl;
    }
    
    separation_test::API::shutdown();
    return 0;
}