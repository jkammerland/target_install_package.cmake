#pragma once
#include <vector>

namespace data {

class Utils {
public:
    static std::vector<int> range(int start, int end);
    static int sum(const std::vector<int>& values);
};

} // namespace data