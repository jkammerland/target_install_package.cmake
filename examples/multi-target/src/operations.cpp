#include "math/operations.h"
#include <cmath>

namespace math {

double Operations::power(double base, double exponent) {
  return std::pow(base, exponent);
}

double Operations::squareRoot(double value) { return std::sqrt(value); }

double Operations::factorial(int n) {
  if (n <= 1)
    return 1.0;
  double result = 1.0;
  for (int i = 2; i <= n; ++i) {
    result *= i;
  }
  return result;
}

bool Operations::isPrime(int n) {
  if (n <= 1)
    return false;
  if (n <= 3)
    return true;
  if (n % 2 == 0 || n % 3 == 0)
    return false;

  for (int i = 5; i * i <= n; i += 6) {
    if (n % i == 0 || n % (i + 2) == 0) {
      return false;
    }
  }
  return true;
}

int Operations::gcd(int a, int b) {
  while (b != 0) {
    int temp = b;
    b = a % b;
    a = temp;
  }
  return a;
}

int Operations::lcm(int a, int b) { return (a * b) / gcd(a, b); }

} // namespace math