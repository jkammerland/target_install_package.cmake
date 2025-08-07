#include "data/utils.h"
#include <numeric>

namespace data {

std::vector<int> Utils::range(int start, int end) {
    std::vector<int> result;
    for (int i = start; i < end; ++i) {
        result.push_back(i);
    }
    return result;
}

int Utils::sum(const std::vector<int>& values) {
    return std::accumulate(values.begin(), values.end(), 0);
}

} // namespace data