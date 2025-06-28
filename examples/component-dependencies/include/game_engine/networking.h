#pragma once

#include <string>

namespace GameEngine {

/**
 * Networking component - requires Boost when used
 * 
 * Component dependencies:
 * - Boost 1.79 REQUIRED COMPONENTS system network
 */
class Networking {
public:
    void initializeNetworking();
    void startServer(int port);
    void connectToServer(const std::string& address, int port);
    void sendData(const std::string& data);
    void disconnect();
    
    bool isNetworkingInitialized() const;
    bool isConnected() const;
    
private:
    bool m_networkingInitialized = false;
    bool m_connected = false;
    int m_port = 0;
};

} // namespace GameEngine