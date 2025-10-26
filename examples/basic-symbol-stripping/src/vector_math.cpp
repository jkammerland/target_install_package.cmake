#include "vector_math.h"

#include <cmath>
#include <numeric>
#include <stdexcept>

namespace vector_math {

double dot(const std::vector<double>& lhs, const std::vector<double>& rhs) {
  if (lhs.size() != rhs.size()) {
    throw std::invalid_argument("dot: vectors must have the same length");
  }
  return std::inner_product(lhs.begin(), lhs.end(), rhs.begin(), 0.0);
}

double norm(const std::vector<double>& values) {
  return std::sqrt(std::inner_product(values.begin(), values.end(), values.begin(), 0.0));
}

}  // namespace vector_math
