#include "intapp/library.h"

namespace intapp {

std::string getVersion() {
    return "1.5.0";
}

std::string getWelcomeMessage() {
    return "Welcome to Integrated Example - CPack + Container Integration!";
}

std::string processData(const std::string& input) {
    return "Processed: " + input;
}

}