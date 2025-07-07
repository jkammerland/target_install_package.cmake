#pragma once

// BSD Licensed Dependency Header  
namespace bsd_dep {

class BSDFeature {
public:
    static double process(double value) { return value * 1.5; }
    static const char* get_license() { return "BSD 3-Clause"; }
};

} // namespace bsd_dep