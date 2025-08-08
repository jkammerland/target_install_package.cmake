#pragma once

#include <string>
#include <memory>

// Forward declarations to avoid dependency on libA headers for consumers
namespace libA {
    class Core;
}

namespace libB {

class Engine {
public:
    Engine();
    ~Engine();

    bool start();
    bool stop();
    bool isRunning() const;
    
    std::string getStatus() const;
    void processData(const std::string& data);

private:
    std::unique_ptr<libA::Core> coreSystem_;
    bool running_;
};

} // namespace libB