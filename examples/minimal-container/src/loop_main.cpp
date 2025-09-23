#include <iostream>
#include <thread>
#include <chrono>
#include <csignal>
#include <atomic>

std::atomic<bool> running{true};

void signal_handler(int signal) {
    std::cout << "\nReceived signal " << signal << ", shutting down gracefully...\n";
    running = false;
}

int main(int argc, char* argv[]) {
    // Register signal handlers
    std::signal(SIGTERM, signal_handler);
    std::signal(SIGINT, signal_handler);

    std::cout << "Starting loop container (PID: " << getpid() << ")\n";

    int iteration = 0;
    while (running) {
        std::cout << "[" << std::chrono::system_clock::now().time_since_epoch().count()
                  << "] Iteration " << ++iteration;

        if (argc > 1) {
            std::cout << " - Args:";
            for (int i = 1; i < argc; ++i) {
                std::cout << " " << argv[i];
            }
        }
        std::cout << std::endl;
        std::cout.flush();

        std::this_thread::sleep_for(std::chrono::seconds(2));
    }

    std::cout << "Container shutdown complete after " << iteration << " iterations\n";
    return 0;
}