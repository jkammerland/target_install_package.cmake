#include <iostream>
#include <thread>
#include <chrono>
#include <csignal>
#include <atomic>
#include <vector>
#include "utils/string_utils.h"

std::atomic<bool> running{true};

void signal_handler(int signal) {
    std::cout << "\nApp3: Received signal " << signal << ", shutting down...\n";
    running = false;
}

int main() {
    // Set up signal handler for graceful shutdown
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);
    
    std::cout << "App3 starting (long-running service)...\n";
    std::cout << "Press Ctrl+C to stop\n";
    
    int counter = 0;
    std::vector<std::string> messages = {"Running", "Active", "Processing", "Working"};
    
    while (running) {
        std::string msg = messages[counter % messages.size()];
        std::cout << "App3 heartbeat #" << ++counter << " - Status: " 
                  << utils::StringUtils::toUpper(msg) << "\n";
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }
    
    std::cout << "App3 shutdown complete\n";
    return 0;
}