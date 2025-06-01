export module math;

import <cmath>;

// Export the math namespace
export namespace math {

// Basic arithmetic operations
export constexpr double add(double a, double b) {
    return a + b;
}

export constexpr double subtract(double a, double b) {
    return a - b;
}

export constexpr double multiply(double a, double b) {
    return a * b;
}

export double divide(double a, double b) {
    if (b == 0.0) {
        throw std::invalid_argument("Division by zero");
    }
    return a / b;
}

// Advanced mathematical functions
export double power(double base, double exponent) {
    return std::pow(base, exponent);
}

export double square_root(double value) {
    if (value < 0.0) {
        throw std::invalid_argument("Square root of negative number");
    }
    return std::sqrt(value);
}

export double logarithm(double value, double base = std::numbers::e) {
    if (value <= 0.0 || base <= 0.0 || base == 1.0) {
        throw std::invalid_argument("Invalid logarithm arguments");
    }
    return std::log(value) / std::log(base);
}

// Constants
export constexpr double PI = 3.14159265358979323846;
export constexpr double E = 2.71828182845904523536;

} // namespace math