#pragma once

#include <string>

namespace libA {

class Core {
public:
    Core();
    ~Core();

    std::string getVersion() const;
    int initialize();
    void shutdown();

private:
    bool initialized_;
};

} // namespace libA