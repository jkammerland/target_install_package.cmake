#pragma once

#include <string>
#include <vector>

namespace media {

enum class MediaType { AUDIO, VIDEO, IMAGE };

class MediaCore {
public:
  static bool initialize();
  static void shutdown();

  static bool loadMedia(const std::string &filename, MediaType type);
  static void unloadMedia(const std::string &filename);
  static std::vector<std::string> getLoadedMedia();

  static bool playAudio(const std::string &filename);
  static bool playVideo(const std::string &filename);
  static bool displayImage(const std::string &filename);

  static void setVolume(float volume);
  static float getVolume();

private:
  static bool initialized;
  static float currentVolume;
  static std::vector<std::string> loadedFiles;
};

} // namespace media