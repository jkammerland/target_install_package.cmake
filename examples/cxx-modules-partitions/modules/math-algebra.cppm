// Module partition interface unit for algebra operations
module;

// Global module fragment - includes must go here
#include <cmath>
#include <stdexcept>
#include <vector>
#include <algorithm>

export module math:algebra;

// Export basic arithmetic operations
export namespace algebra {
    
    // Basic arithmetic operations
    double add(double a, double b) {
        return a + b;
    }
    
    double subtract(double a, double b) {
        return a - b;
    }
    
    double multiply(double a, double b) {
        return a * b;
    }
    
    double divide(double a, double b) {
        if (b == 0.0) {
            throw std::invalid_argument("Division by zero");
        }
        return a / b;
    }
    
    // Power operations
    double power(double base, double exponent) {
        return std::pow(base, exponent);
    }
    
    double square_root(double value) {
        if (value < 0.0) {
            throw std::invalid_argument("Square root of negative number");
        }
        return std::sqrt(value);
    }
    
    double logarithm(double value, double base = std::numbers::e) {
        if (value <= 0.0 || base <= 0.0 || base == 1.0) {
            throw std::invalid_argument("Invalid logarithm arguments");
        }
        return std::log(value) / std::log(base);
    }
    
    // Mathematical constants
    inline constexpr double PI = 3.14159265358979323846;
    inline constexpr double E = 2.71828182845904523536;
    inline constexpr double GOLDEN_RATIO = 1.61803398874989484820;
    
    // Linear algebra operations
    class Matrix2x2 {
    private:
        double data[2][2];
        
    public:
        Matrix2x2(double a11, double a12, double a21, double a22) {
            data[0][0] = a11; data[0][1] = a12;
            data[1][0] = a21; data[1][1] = a22;
        }
        
        double determinant() const {
            return data[0][0] * data[1][1] - data[0][1] * data[1][0];
        }
        
        Matrix2x2 multiply(const Matrix2x2& other) const {
            return Matrix2x2(
                data[0][0] * other.data[0][0] + data[0][1] * other.data[1][0],
                data[0][0] * other.data[0][1] + data[0][1] * other.data[1][1],
                data[1][0] * other.data[0][0] + data[1][1] * other.data[1][0],
                data[1][0] * other.data[0][1] + data[1][1] * other.data[1][1]
            );
        }
        
        double get(int row, int col) const {
            return data[row][col];
        }
    };
    
    // Vector operations
    class Vector2D {
    private:
        double x, y;
        
    public:
        Vector2D(double x_val, double y_val) : x(x_val), y(y_val) {}
        
        double magnitude() const {
            return square_root(x * x + y * y);
        }
        
        Vector2D add(const Vector2D& other) const {
            return Vector2D(x + other.x, y + other.y);
        }
        
        Vector2D subtract(const Vector2D& other) const {
            return Vector2D(x - other.x, y - other.y);
        }
        
        Vector2D scale(double factor) const {
            return Vector2D(x * factor, y * factor);
        }
        
        double dot_product(const Vector2D& other) const {
            return x * other.x + y * other.y;
        }
        
        double get_x() const { return x; }
        double get_y() const { return y; }
    };
    
    // Polynomial operations
    class Polynomial {
    private:
        std::vector<double> coefficients;  // coefficients[i] is coefficient of x^i
        
    public:
        Polynomial(const std::vector<double>& coeffs) : coefficients(coeffs) {}
        
        double evaluate(double x) const {
            double result = 0.0;
            double x_power = 1.0;
            for (double coeff : coefficients) {
                result += coeff * x_power;
                x_power *= x;
            }
            return result;
        }
        
        Polynomial add(const Polynomial& other) const {
            size_t max_size = std::max(coefficients.size(), other.coefficients.size());
            std::vector<double> result(max_size, 0.0);
            
            for (size_t i = 0; i < coefficients.size(); ++i) {
                result[i] += coefficients[i];
            }
            for (size_t i = 0; i < other.coefficients.size(); ++i) {
                result[i] += other.coefficients[i];
            }
            
            return Polynomial(result);
        }
        
        Polynomial derivative() const {
            if (coefficients.size() <= 1) {
                return Polynomial({0.0});
            }
            
            std::vector<double> result;
            for (size_t i = 1; i < coefficients.size(); ++i) {
                result.push_back(coefficients[i] * i);
            }
            
            return Polynomial(result);
        }
        
        int degree() const {
            return static_cast<int>(coefficients.size()) - 1;
        }
    };
    
    // Equation solving
    struct QuadraticSolution {
        bool has_real_solutions;
        double solution1;
        double solution2;
    };
    
    QuadraticSolution solve_quadratic(double a, double b, double c) {
        if (a == 0.0) {
            throw std::invalid_argument("Coefficient 'a' cannot be zero for quadratic equation");
        }
        
        double discriminant = b * b - 4 * a * c;
        
        if (discriminant < 0) {
            return QuadraticSolution{false, 0.0, 0.0};
        }
        
        double sqrt_discriminant = square_root(discriminant);
        double solution1 = (-b + sqrt_discriminant) / (2 * a);
        double solution2 = (-b - sqrt_discriminant) / (2 * a);
        
        return QuadraticSolution{true, solution1, solution2};
    }
}

// Internal helper functions (not exported)
namespace {
    bool is_close(double a, double b, double epsilon = 1e-10) {
        return std::abs(a - b) < epsilon;
    }
}