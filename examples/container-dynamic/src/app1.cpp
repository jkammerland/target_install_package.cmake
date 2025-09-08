#include <iostream>
#include <thread>
#include <chrono>
#include "utils/string_utils.h"

int main() {
    std::cout << "App1 starting...\n";
    
    std::string text = "Hello from App1";
    std::cout << "Original: " << text << "\n";
    std::cout << "Uppercase: " << utils::StringUtils::toUpper(text) << "\n";
    std::cout << "Lowercase: " << utils::StringUtils::toLower(text) << "\n";
    
    // Simulate some work
    for (int i = 0; i < 5; ++i) {
        std::cout << "App1 working... " << i << "\n";
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
    
    std::cout << "App1 completed successfully!\n";
    return 0;
}