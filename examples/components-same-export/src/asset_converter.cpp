#include <iostream>
#include <vector>
#include <string>

void printUsage(const char* programName) {
    std::cout << "Usage: " << programName << " [options] input_file output_file\n";
    std::cout << "Options:\n";
    std::cout << "  -f, --format FORMAT   Output format (auto-detected if not specified)\n";
    std::cout << "  -q, --quality QUALITY Quality level (1-100, default: 85)\n";
    std::cout << "  -h, --help           Show this help message\n";
    std::cout << "\nSupported formats:\n";
    std::cout << "  Images: jpg, png, bmp\n";
    std::cout << "  Videos: mp4, avi, mov\n";
    std::cout << "  Audio: mp3, wav, flac\n";
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 1;
    }
    
    std::vector<std::string> args(argv + 1, argv + argc);
    
    if (args[0] == "-h" || args[0] == "--help") {
        printUsage(argv[0]);
        return 0;
    }
    
    if (args.size() < 2) {
        std::cerr << "Error: Input and output files required\n";
        printUsage(argv[0]);
        return 1;
    }
    
    std::string inputFile = args[args.size() - 2];
    std::string outputFile = args[args.size() - 1];
    
    std::string format = "auto";
    int quality = 85;
    
    // Parse options
    for (size_t i = 0; i < args.size() - 2; ++i) {
        if (args[i] == "-f" || args[i] == "--format") {
            if (i + 1 < args.size() - 2) {
                format = args[++i];
            }
        } else if (args[i] == "-q" || args[i] == "--quality") {
            if (i + 1 < args.size() - 2) {
                quality = std::stoi(args[++i]);
            }
        }
    }
    
    std::cout << "Asset Converter Tool\n";
    std::cout << "====================\n";
    std::cout << "Input file: " << inputFile << "\n";
    std::cout << "Output file: " << outputFile << "\n";
    std::cout << "Format: " << format << "\n";
    std::cout << "Quality: " << quality << "\n";
    std::cout << "\nConverting asset...\n";
    
    // Simulate conversion process
    std::cout << "Conversion completed successfully!\n";
    
    return 0;
}