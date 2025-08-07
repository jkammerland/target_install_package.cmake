#include "cbor_tags/tags.h"
#include "cbor_tags/parser.h"

namespace cbor {

bool Tags::isValid(int tag) {
    return tag >= 0 && tag <= 3;
}

const char* Tags::getName(int tag) {
    switch(tag) {
        case DATE_TIME: return "DateTime";
        case EPOCH_TIME: return "EpochTime";
        case POSITIVE_BIGNUM: return "PositiveBignum";
        case NEGATIVE_BIGNUM: return "NegativeBignum";
        default: return "Unknown";
    }
}

Parser::Parser() : lastTag(-1) {}

bool Parser::parseTag(const unsigned char* data, size_t length) {
    if (length > 0) {
        lastTag = data[0];
        return Tags::isValid(lastTag);
    }
    return false;
}

} // namespace cbor