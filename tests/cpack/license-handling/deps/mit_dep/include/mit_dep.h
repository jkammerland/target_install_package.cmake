#pragma once

// MIT Licensed Dependency Header
namespace mit_dep {

class MITFeature {
public:
    static int process(int input) { return input * 2; }
    static const char* get_license() { return "MIT"; }
};

} // namespace mit_dep