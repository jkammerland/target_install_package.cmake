module source_math;

namespace source_math {

int add(int left, int right) {
  return left + right;
}

double average(int left, int right) {
  return static_cast<double>(add(left, right)) / 2.0;
}

} // namespace source_math
