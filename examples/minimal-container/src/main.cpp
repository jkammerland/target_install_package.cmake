#include <iostream>
#include <thread>
#include <chrono>
#include <cmath>

int main(int argc, char* argv[]) {
    std::cout << "Hello from minimal container!\n";
    std::cout << "Version: 1.0.0\n";

    // Use some C++ standard library features to ensure we need libstdc++
    std::cout << "Testing C++ stdlib...\n";

    // Thread test
    std::thread t([]() {
        std::cout << "  Thread support: OK\n";
    });
    t.join();

    // Math test
    double result = std::sin(3.14159 / 4);
    std::cout << "  Math support: OK (sin(π/4) = " << result << ")\n";

    // Time test
    auto now = std::chrono::system_clock::now();
    std::cout << "  Chrono support: OK\n";

    if (argc > 1) {
        std::cout << "Arguments passed:";
        for (int i = 1; i < argc; ++i) {
            std::cout << " " << argv[i];
        }
        std::cout << "\n";
    }

    std::cout << "Container test successful!\n";
    return 0;
}