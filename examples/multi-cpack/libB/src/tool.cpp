#include "libB/engine.h"
#include "libB/tools.h"
#include <iostream>
#include <vector>

int main(int argc, char* argv[]) {
    std::cout << "LibB Command Line Tool\n";
    std::cout << "======================\n\n";
    
    // Print diagnostics
    libB::Tools::printDiagnostics();
    
    // Create and start engine
    libB::Engine engine;
    if (!engine.start()) {
        std::cerr << "Failed to start engine\n";
        return 1;
    }
    
    std::cout << "\nEngine Status: " << engine.getStatus() << "\n";
    
    // Process some sample data
    if (argc > 1) {
        std::cout << "\nProcessing command line arguments:\n";
        for (int i = 1; i < argc; ++i) {
            engine.processData(argv[i]);
        }
    } else {
        std::cout << "\nProcessing sample data:\n";
        engine.processData("apple,banana,cherry");
    }
    
    // Generate a report
    std::vector<std::string> reportData = {"Task 1", "Task 2", "Task 3"};
    std::cout << "\n" << libB::Tools::generateReport(reportData);
    
    // Stop engine
    engine.stop();
    
    return 0;
}