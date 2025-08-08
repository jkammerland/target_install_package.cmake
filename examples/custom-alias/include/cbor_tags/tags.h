#pragma once

namespace cbor {

class Tags {
public:
    static constexpr int DATE_TIME = 0;
    static constexpr int EPOCH_TIME = 1;
    static constexpr int POSITIVE_BIGNUM = 2;
    static constexpr int NEGATIVE_BIGNUM = 3;
    
    static bool isValid(int tag);
    static const char* getName(int tag);
};

} // namespace cbor