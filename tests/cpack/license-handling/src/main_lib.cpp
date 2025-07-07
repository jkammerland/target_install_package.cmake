#include "license_test/api.h"
#include <iostream>
#include <sstream>

namespace license_test {

bool API::initialize() {
    std::cout << "Initializing LicenseTest API with multiple licensed dependencies" << std::endl;
    return true;
}

void API::shutdown() {
    std::cout << "Shutting down LicenseTest API" << std::endl;
}

const char* API::version() {
    return "1.2.3";
}

int API::use_mit_feature(int input) {
    return mit_dep::MITFeature::process(input);
}

void API::use_apache_feature(const char* data) {
    apache_dep::ApacheFeature::process(data);
}

double API::use_bsd_feature(double value) {
    return bsd_dep::BSDFeature::process(value);
}

const char* API::get_license_info() {
    static std::string license_info = 
        "LicenseTest uses:\n"
        "- MIT dependency (" + std::string(mit_dep::MITFeature::get_license()) + ")\n"
        "- Apache dependency (" + std::string(apache_dep::ApacheFeature::get_license()) + ")\n" 
        "- BSD dependency (" + std::string(bsd_dep::BSDFeature::get_license()) + ")\n"
        "See NOTICE file and licenses/ directory for full license information.";
    return license_info.c_str();
}

} // namespace license_test