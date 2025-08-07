#pragma once

namespace data {

class Core {
public:
    static void initialize();
    static void shutdown();
    static bool isInitialized();
    
private:
    static bool initialized;
};

} // namespace data