#pragma once
#include <cstddef>

namespace cbor {

class Parser {
public:
    Parser();
    bool parseTag(const unsigned char* data, size_t length);
    int getLastTag() const { return lastTag; }
    
private:
    int lastTag;
};

} // namespace cbor