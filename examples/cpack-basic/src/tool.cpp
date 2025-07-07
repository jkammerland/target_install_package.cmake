#include "cpack_lib/core.h"
#include <iostream>
#include <string>

int main(int argc, char *argv[]) {
  std::cout << "MyLib Tool v" << mylib::Core::version() << std::endl;

  if (!mylib::Core::initialize()) {
    std::cerr << "Failed to initialize MyLib" << std::endl;
    return 1;
  }

  if (argc > 1) {
    std::string command = argv[1];
    if (command == "--version" || command == "-v") {
      std::cout << "Version: " << mylib::Core::version() << std::endl;
    } else if (command == "--help" || command == "-h") {
      std::cout << "Usage: mytool [--version|-v] [--help|-h]" << std::endl;
      std::cout << "  --version, -v  Show version" << std::endl;
      std::cout << "  --help, -h     Show this help" << std::endl;
    } else {
      std::cout << "Processing: " << command << std::endl;
    }
  } else {
    std::cout << "MyLib tool ready. Use --help for usage." << std::endl;
  }

  mylib::Core::shutdown();
  return 0;
}