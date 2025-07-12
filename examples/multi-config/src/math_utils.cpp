#include "utils/math_utils.h"
#include <algorithm>

namespace utils {

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}

int max(int a, int b) {
    return std::max(a, b);
}

} // namespace utils