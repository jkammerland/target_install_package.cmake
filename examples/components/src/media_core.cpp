#include "media/core.h"
#include <iostream>
#include <algorithm>

namespace media {

bool MediaCore::initialized = false;
float MediaCore::currentVolume = 1.0f;
std::vector<std::string> MediaCore::loadedFiles;

bool MediaCore::initialize() {
    if (initialized) return true;
    
    std::cout << "Initializing Media Core..." << std::endl;
    initialized = true;
    return true;
}

void MediaCore::shutdown() {
    if (!initialized) return;
    
    std::cout << "Shutting down Media Core..." << std::endl;
    loadedFiles.clear();
    initialized = false;
}

bool MediaCore::loadMedia(const std::string& filename, MediaType type) {
    if (!initialized) {
        std::cerr << "Media Core not initialized" << std::endl;
        return false;
    }
    
    auto it = std::find(loadedFiles.begin(), loadedFiles.end(), filename);
    if (it == loadedFiles.end()) {
        loadedFiles.push_back(filename);
        std::cout << "Loaded media: " << filename << std::endl;
    }
    
    return true;
}

void MediaCore::unloadMedia(const std::string& filename) {
    auto it = std::find(loadedFiles.begin(), loadedFiles.end(), filename);
    if (it != loadedFiles.end()) {
        loadedFiles.erase(it);
        std::cout << "Unloaded media: " << filename << std::endl;
    }
}

std::vector<std::string> MediaCore::getLoadedMedia() {
    return loadedFiles;
}

bool MediaCore::playAudio(const std::string& filename) {
    std::cout << "Playing audio: " << filename << " (Volume: " << currentVolume << ")" << std::endl;
    return true;
}

bool MediaCore::playVideo(const std::string& filename) {
    std::cout << "Playing video: " << filename << std::endl;
    return true;
}

bool MediaCore::displayImage(const std::string& filename) {
    std::cout << "Displaying image: " << filename << std::endl;
    return true;
}

void MediaCore::setVolume(float volume) {
    currentVolume = std::max(0.0f, std::min(1.0f, volume));
}

float MediaCore::getVolume() {
    return currentVolume;
}

} // namespace media