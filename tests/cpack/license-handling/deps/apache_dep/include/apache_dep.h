#pragma once

// Apache Licensed Dependency Header
namespace apache_dep {

class ApacheFeature {
public:
    static void process(const char* data) { /* process data */ }
    static const char* get_license() { return "Apache 2.0"; }
};

} // namespace apache_dep