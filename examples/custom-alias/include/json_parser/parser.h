#pragma once
#include <string>

namespace json {

class Parser {
public:
    Parser();
    bool parse(const std::string& json);
    bool isValid() const { return valid; }
    
private:
    bool valid;
};

} // namespace json