#pragma once

#include <string>
#include <vector>

namespace media {

struct MediaInfo {
    std::string filename;
    std::string format;
    long long fileSize;
    int width;
    int height;
    double duration;
};

class DevTools {
public:
    static MediaInfo analyzeFile(const std::string& filename);
    static bool validateFormat(const std::string& filename);
    static std::vector<std::string> getSupportedFormats();
    
    static bool optimizeImage(const std::string& input, const std::string& output, int quality = 85);
    static bool compressVideo(const std::string& input, const std::string& output, int bitrate = 1000);
    static bool normalizeAudio(const std::string& input, const std::string& output, float targetLevel = -16.0f);
    
    static void generateReport(const std::vector<std::string>& files, const std::string& outputFile);
    static bool batchProcess(const std::vector<std::string>& files, const std::string& operation);
};

} // namespace media