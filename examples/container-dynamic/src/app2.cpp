#include <iostream>
#include <thread>
#include <chrono>
#include <vector>
#include "utils/string_utils.h"

int main() {
    std::cout << "App2 starting...\n";
    
    // Different behavior from app1
    std::vector<std::string> words = {"Container", "Memory", "Sharing"};
    for (int i = 0; i < 3; ++i) {
        std::string word = words[i];
        std::cout << "App2 processing: " << word << "\n";
        std::cout << "  Uppercase: " << utils::StringUtils::toUpper(word) << "\n";
        std::cout << "  Lowercase: " << utils::StringUtils::toLower(word) << "\n";
        std::this_thread::sleep_for(std::chrono::seconds(3));
    }
    
    std::cout << "App2 completed successfully!\n";
    return 0;
}