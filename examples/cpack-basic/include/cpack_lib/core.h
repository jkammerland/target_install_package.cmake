#pragma once

namespace mylib {

class Core {
public:
    static bool initialize();
    static void shutdown();
    static const char* version();
    
private:
    static bool initialized_;
};

} // namespace mylib