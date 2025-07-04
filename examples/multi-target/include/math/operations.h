#pragma once

namespace math {

class Operations {
public:
  static double power(double base, double exponent);
  static double squareRoot(double value);
  static double factorial(int n);
  static bool isPrime(int n);
  static int gcd(int a, int b);
  static int lcm(int a, int b);
};

} // namespace math