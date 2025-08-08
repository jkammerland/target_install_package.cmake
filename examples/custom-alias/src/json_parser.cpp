#include "json_parser/parser.h"
#include "json_parser/utils.h"

namespace json {

Parser::Parser() : valid(false) {}

bool Parser::parse(const std::string& json) {
    // Simplified validation
    valid = !json.empty() && json[0] == '{' && json[json.length()-1] == '}';
    return valid;
}

std::string Utils::escape(const std::string& str) {
    std::string result;
    for (char c : str) {
        if (c == '"') result += "\\\"";
        else if (c == '\\') result += "\\\\";
        else result += c;
    }
    return result;
}

std::string Utils::unescape(const std::string& str) {
    std::string result;
    bool escape = false;
    for (char c : str) {
        if (escape) {
            if (c == '"' || c == '\\') result += c;
            escape = false;
        } else if (c == '\\') {
            escape = true;
        } else {
            result += c;
        }
    }
    return result;
}

} // namespace json