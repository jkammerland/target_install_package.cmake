// Module partition interface unit for calculus operations
module;

// Global module fragment - includes must go here
#include <functional>
#include <cmath>
#include <stdexcept>
#include <vector>
#include <algorithm>

export module math:calculus;

// Import algebra partition for mathematical operations
import :algebra;

// Export calculus operations
export namespace calculus {
    
    // Function type alias for mathematical functions
    using Function = std::function<double(double)>;
    using Function2D = std::function<double(double, double)>;
    
    // Numerical differentiation
    double derivative(const Function& f, double x, double h = 1e-8) {
        // Use central difference formula: f'(x) ≈ (f(x+h) - f(x-h)) / (2h)
        if (h <= 0) {
            throw std::invalid_argument("Step size h must be positive");
        }
        return (f(x + h) - f(x - h)) / (2 * h);
    }
    
    double second_derivative(const Function& f, double x, double h = 1e-5) {
        // f''(x) ≈ (f(x+h) - 2f(x) + f(x-h)) / h²
        if (h <= 0) {
            throw std::invalid_argument("Step size h must be positive");
        }
        return (f(x + h) - 2 * f(x) + f(x - h)) / (h * h);
    }
    
    // Numerical integration using various methods
    double rectangular_rule(const Function& f, double a, double b, int n) {
        if (n <= 0) {
            throw std::invalid_argument("Number of intervals must be positive");
        }
        if (a > b) {
            std::swap(a, b);
        }
        
        double h = (b - a) / n;
        double sum = 0.0;
        
        for (int i = 0; i < n; ++i) {
            sum += f(a + i * h);
        }
        
        return sum * h;
    }
    
    double trapezoidal_rule(const Function& f, double a, double b, int n) {
        if (n <= 0) {
            throw std::invalid_argument("Number of intervals must be positive");
        }
        if (a > b) {
            std::swap(a, b);
        }
        
        double h = (b - a) / n;
        double sum = 0.5 * (f(a) + f(b));
        
        for (int i = 1; i < n; ++i) {
            sum += f(a + i * h);
        }
        
        return sum * h;
    }
    
    double simpsons_rule(const Function& f, double a, double b, int n) {
        if (n % 2 != 0) {
            throw std::invalid_argument("Number of intervals must be even for Simpson's rule");
        }
        if (n <= 0) {
            throw std::invalid_argument("Number of intervals must be positive");
        }
        if (a > b) {
            std::swap(a, b);
        }
        
        double h = (b - a) / n;
        double sum = f(a) + f(b);
        
        // Add odd-indexed terms (coefficient 4)
        for (int i = 1; i < n; i += 2) {
            sum += 4 * f(a + i * h);
        }
        
        // Add even-indexed terms (coefficient 2)
        for (int i = 2; i < n; i += 2) {
            sum += 2 * f(a + i * h);
        }
        
        return sum * h / 3.0;
    }
    
    // Adaptive integration with error estimation
    double adaptive_integrate(const Function& f, double a, double b, double tolerance = 1e-10) {
        auto simpson = [&](double x1, double x2, int intervals) {
            return simpsons_rule(f, x1, x2, intervals);
        };
        
        // Start with coarse approximation
        double coarse = simpson(a, b, 2);
        double fine = simpson(a, b, 4);
        
        if (std::abs(fine - coarse) < tolerance) {
            return fine;
        }
        
        // Recursively refine
        double mid = (a + b) / 2;
        return adaptive_integrate(f, a, mid, tolerance / 2) + 
               adaptive_integrate(f, mid, b, tolerance / 2);
    }
    
    // Simple integration wrapper for most use cases
    double simple_integrate(const Function& f, double a, double b, int n = 1000) {
        return simpsons_rule(f, a, b, n);
    }
    
    // Root finding using Newton-Raphson method
    double newton_raphson(const Function& f, double x0, double tolerance = 1e-10, int max_iterations = 100) {
        double x = x0;
        
        for (int i = 0; i < max_iterations; ++i) {
            double fx = f(x);
            double fpx = derivative(f, x);
            
            if (std::abs(fpx) < tolerance) {
                throw std::runtime_error("Derivative too close to zero");
            }
            
            double x_new = x - fx / fpx;
            
            if (std::abs(x_new - x) < tolerance) {
                return x_new;
            }
            
            x = x_new;
        }
        
        throw std::runtime_error("Newton-Raphson failed to converge");
    }
    
    // Root finding using bisection method
    double bisection_method(const Function& f, double a, double b, double tolerance = 1e-10) {
        if (f(a) * f(b) > 0) {
            throw std::invalid_argument("Function must have opposite signs at endpoints");
        }
        
        while (std::abs(b - a) > tolerance) {
            double c = (a + b) / 2;
            
            if (f(a) * f(c) < 0) {
                b = c;
            } else {
                a = c;
            }
        }
        
        return (a + b) / 2;
    }
    
    // Optimization using golden section search
    double golden_section_search(const Function& f, double a, double b, double tolerance = 1e-10) {
        const double phi = algebra::GOLDEN_RATIO;
        const double resphi = 2 - phi;
        
        double tol1 = tolerance;
        double c = a + resphi * (b - a);
        double d = a + (1 - resphi) * (b - a);
        double fc = f(c);
        double fd = f(d);
        
        while (std::abs(b - a) > tol1) {
            if (fc < fd) {
                b = d;
                d = c;
                fd = fc;
                c = a + resphi * (b - a);
                fc = f(c);
            } else {
                a = c;
                c = d;
                fc = fd;
                d = a + (1 - resphi) * (b - a);
                fd = f(d);
            }
        }
        
        return (a + b) / 2;
    }
    
    // Series expansions
    double taylor_series_exp(double x, int terms = 20) {
        double result = 1.0;  // First term is 1
        double term = 1.0;
        
        for (int n = 1; n < terms; ++n) {
            term *= x / n;  // x^n / n!
            result += term;
        }
        
        return result;
    }
    
    double taylor_series_sin(double x, int terms = 20) {
        double result = x;  // First term is x
        double term = x;
        
        for (int n = 1; n < terms; ++n) {
            term *= -x * x / ((2 * n) * (2 * n + 1));  // Alternating series
            result += term;
        }
        
        return result;
    }
    
    double taylor_series_cos(double x, int terms = 20) {
        double result = 1.0;  // First term is 1
        double term = 1.0;
        
        for (int n = 1; n < terms; ++n) {
            term *= -x * x / ((2 * n - 1) * (2 * n));  // Alternating series
            result += term;
        }
        
        return result;
    }
    
    // Differential equation solving (Euler's method)
    std::vector<std::pair<double, double>> euler_method(
        const Function2D& dydx,  // dy/dx = f(x, y)
        double x0, double y0,    // Initial conditions
        double h,                // Step size
        double x_end             // End point
    ) {
        std::vector<std::pair<double, double>> solution;
        
        double x = x0;
        double y = y0;
        
        solution.emplace_back(x, y);
        
        while (x < x_end) {
            y = y + h * dydx(x, y);
            x = x + h;
            solution.emplace_back(x, y);
        }
        
        return solution;
    }
    
    // Runge-Kutta 4th order method
    std::vector<std::pair<double, double>> runge_kutta_4(
        const Function2D& dydx,  // dy/dx = f(x, y)
        double x0, double y0,    // Initial conditions
        double h,                // Step size
        double x_end             // End point
    ) {
        std::vector<std::pair<double, double>> solution;
        
        double x = x0;
        double y = y0;
        
        solution.emplace_back(x, y);
        
        while (x < x_end) {
            double k1 = h * dydx(x, y);
            double k2 = h * dydx(x + h/2, y + k1/2);
            double k3 = h * dydx(x + h/2, y + k2/2);
            double k4 = h * dydx(x + h, y + k3);
            
            y = y + (k1 + 2*k2 + 2*k3 + k4) / 6;
            x = x + h;
            solution.emplace_back(x, y);
        }
        
        return solution;
    }
    
    // Function analysis
    struct CriticalPoint {
        double x;
        double y;
        enum Type { MINIMUM, MAXIMUM, SADDLE, UNKNOWN } type;
    };
    
    std::vector<CriticalPoint> find_critical_points(const Function& f, double a, double b, int search_points = 100) {
        std::vector<CriticalPoint> points;
        double step = (b - a) / search_points;
        
        for (int i = 1; i < search_points; ++i) {
            double x = a + i * step;
            double fpx = derivative(f, x);
            
            // Look for sign changes in derivative (approximate critical points)
            if (std::abs(fpx) < 1e-6) {
                double fppx = second_derivative(f, x);
                CriticalPoint::Type type = CriticalPoint::UNKNOWN;
                
                if (fppx > 0) {
                    type = CriticalPoint::MINIMUM;
                } else if (fppx < 0) {
                    type = CriticalPoint::MAXIMUM;
                } else {
                    type = CriticalPoint::SADDLE;
                }
                
                points.push_back({x, f(x), type});
            }
        }
        
        return points;
    }
    
    // Compute definite integral bounds for common functions
    double integrate_polynomial_powers(int power, double a, double b) {
        if (power == -1) {
            if (a <= 0 || b <= 0) {
                throw std::invalid_argument("Logarithmic integral requires positive bounds");
            }
            return algebra::logarithm(b) - algebra::logarithm(a);
        }
        
        double coefficient = 1.0 / (power + 1);
        return coefficient * (algebra::power(b, power + 1) - algebra::power(a, power + 1));
    }
}