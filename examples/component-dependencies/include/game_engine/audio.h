#pragma once

namespace GameEngine {

/**
 * Audio component - requires AudioFramework when used
 * 
 * Component dependencies:
 * - AudioFramework 2.1 REQUIRED
 */
class Audio {
public:
    void initializeAudio();
    void playSound(const char* filename);
    void stopSound();
    void setVolume(float volume);
    
    bool isAudioInitialized() const;
    
private:
    bool m_audioInitialized = false;
    float m_volume = 1.0f;
};

} // namespace GameEngine