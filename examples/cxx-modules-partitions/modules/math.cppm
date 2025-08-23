// Primary module interface unit for math library
module;

// Global module fragment - includes must go here
#include <iostream>
#include <memory>
#include <string>

export module math;

// Import and re-export interface partitions
export import :algebra;
export import :geometry;
export import :calculus;

// Forward declare implementation functions
void log_calculator_operation(const std::string& operation, double operand1, double operand2, double result);

// Primary module exports - Calculator class that uses all partitions
export class Calculator {
private:
    double accumulator = 0.0;
    bool verbose_logging = false;
    
public:
    Calculator(bool verbose = false) : verbose_logging(verbose) {}
    
    void reset() { 
        accumulator = 0.0;
        if (verbose_logging) {
            log_calculator_operation("reset", 0, 0, accumulator);
        }
    }
    
    // Algebra operations
    void add(double value) {
        double old_value = accumulator;
        accumulator = algebra::add(accumulator, value);
        if (verbose_logging) {
            log_calculator_operation("add", old_value, value, accumulator);
        }
    }
    
    void subtract(double value) {
        double old_value = accumulator;
        accumulator = algebra::subtract(accumulator, value);
        if (verbose_logging) {
            log_calculator_operation("subtract", old_value, value, accumulator);
        }
    }
    
    void multiply_by(double value) {
        double old_value = accumulator;
        accumulator = algebra::multiply(accumulator, value);
        if (verbose_logging) {
            log_calculator_operation("multiply", old_value, value, accumulator);
        }
    }
    
    void divide_by(double value) {
        double old_value = accumulator;
        accumulator = algebra::divide(accumulator, value);
        if (verbose_logging) {
            log_calculator_operation("divide", old_value, value, accumulator);
        }
    }
    
    void power(double exponent) {
        double old_value = accumulator;
        accumulator = algebra::power(accumulator, exponent);
        if (verbose_logging) {
            log_calculator_operation("power", old_value, exponent, accumulator);
        }
    }
    
    double result() const { 
        return accumulator; 
    }
    
    void set_verbose(bool verbose) {
        verbose_logging = verbose;
    }
};

// Export functions that demonstrate cross-partition usage
export double calculate_sphere_volume(double radius) {
    // Uses geometry partition functions
    return geometry::sphere_volume(radius);
}

export double calculate_circle_area_integral(double radius) {
    // Uses calculus partition to integrate for circle area
    // This demonstrates partitions working together
    auto circle_function = [](double r) { return geometry::circle_area(r); };
    return calculus::simple_integrate(circle_function, 0.0, radius, 100);
}

// Export a comprehensive demonstration function
export void demonstrate_all_partitions() {
    std::cout << "=== Module Partitions Comprehensive Demo ===\n";
    
    std::cout << "\n1. Algebra partition:\n";
    std::cout << "   15 + 25 = " << algebra::add(15, 25) << "\n";
    std::cout << "   100 - 37 = " << algebra::subtract(100, 37) << "\n";
    std::cout << "   7 * 8 = " << algebra::multiply(7, 8) << "\n";
    std::cout << "   144 / 12 = " << algebra::divide(144, 12) << "\n";
    std::cout << "   2^10 = " << algebra::power(2, 10) << "\n";
    std::cout << "   sqrt(25) = " << algebra::square_root(25) << "\n";
    
    std::cout << "\n2. Geometry partition:\n";
    std::cout << "   Circle area (r=5): " << geometry::circle_area(5) << "\n";
    std::cout << "   Rectangle area (4x6): " << geometry::rectangle_area(4, 6) << "\n";
    std::cout << "   Triangle area (b=8, h=5): " << geometry::triangle_area(8, 5) << "\n";
    std::cout << "   Sphere volume (r=3): " << geometry::sphere_volume(3) << "\n";
    std::cout << "   Distance 2D (0,0)-(3,4): " << geometry::distance_2d(0, 0, 3, 4) << "\n";
    
    std::cout << "\n3. Calculus partition:\n";
    auto square_func = [](double x) { return x * x; };
    auto cube_func = [](double x) { return x * x * x; };
    std::cout << "   Derivative of x^2 at x=3: " << calculus::derivative(square_func, 3) << "\n";
    std::cout << "   Integral of x^2 from 0 to 2: " << calculus::simple_integrate(square_func, 0, 2, 1000) << "\n";
    std::cout << "   Integral of x^3 from 0 to 1: " << calculus::simple_integrate(cube_func, 0, 1, 1000) << "\n";
    
    std::cout << "\n4. Calculator class (using all partitions):\n";
    Calculator calc(true);  // Enable verbose logging
    calc.add(50);
    calc.multiply_by(2);
    calc.subtract(25);
    calc.divide_by(5);
    calc.power(2);
    std::cout << "   Final result: " << calc.result() << "\n";
    
    std::cout << "\n5. Cross-partition functions:\n";
    std::cout << "   Sphere volume (r=4): " << calculate_sphere_volume(4) << "\n";
    std::cout << "   Circle area via integration (r=2): " << calculate_circle_area_integral(2) << "\n";
    
    std::cout << "\n=== All partitions working together! ===\n";
}