// Consumer example demonstrating C++20 modules with partitions
#include <iostream>
#include <vector>
#include <cmath>

// Use C++20 modules
import math;

int main() {
    std::cout << "=== Math Library Consumer Example ===\n";
    std::cout << "Using C++20 modules with partitions\n\n";
    
    try {
        // Test 1: Basic algebra operations
        std::cout << "1. Basic Algebra Operations:\n";
        std::cout << "   10 + 15 = " << algebra::add(10, 15) << "\n";
        std::cout << "   25 - 8 = " << algebra::subtract(25, 8) << "\n";
        std::cout << "   6 * 7 = " << algebra::multiply(6, 7) << "\n";
        std::cout << "   48 / 6 = " << algebra::divide(48, 6) << "\n";
        std::cout << "   3^4 = " << algebra::power(3, 4) << "\n";
        std::cout << "   sqrt(49) = " << algebra::square_root(49) << "\n";
        
        // Test 2: Geometry calculations
        std::cout << "\n2. Geometry Calculations:\n";
        std::cout << "   Circle area (r=7): " << geometry::circle_area(7) << "\n";
        std::cout << "   Rectangle area (5x8): " << geometry::rectangle_area(5, 8) << "\n";
        std::cout << "   Triangle area (base=6, height=4): " << geometry::triangle_area(6, 4) << "\n";
        std::cout << "   Sphere volume (r=2): " << geometry::sphere_volume(2) << "\n";
        std::cout << "   Distance 2D (1,1)-(4,5): " << geometry::distance_2d(1, 1, 4, 5) << "\n";
        
        // Test 3: Vector operations
        std::cout << "\n3. Vector Operations:\n";
        algebra::Vector2D v1(3, 4);
        algebra::Vector2D v2(1, 2);
        std::cout << "   Vector v1(3,4) magnitude: " << v1.magnitude() << "\n";
        std::cout << "   Vector v2(1,2) magnitude: " << v2.magnitude() << "\n";
        
        algebra::Vector2D v3 = v1.add(v2);
        std::cout << "   v1 + v2 = (" << v3.get_x() << ", " << v3.get_y() << ")\n";
        
        double dot = v1.dot_product(v2);
        std::cout << "   v1 · v2 = " << dot << "\n";
        
        // Test 4: 3D vector operations
        std::cout << "\n4. 3D Vector Operations:\n";
        geometry::Vector3D v3d1(1, 0, 0);
        geometry::Vector3D v3d2(0, 1, 0);
        
        geometry::Vector3D cross = v3d1.cross_product(v3d2);
        std::cout << "   (1,0,0) × (0,1,0) = (" << cross.get_x() << ", " << cross.get_y() << ", " << cross.get_z() << ")\n";
        
        double angle = v3d1.angle_with(v3d2);
        std::cout << "   Angle between vectors: " << geometry::radians_to_degrees(angle) << " degrees\n";
        
        // Test 5: Calculus operations
        std::cout << "\n5. Calculus Operations:\n";
        
        // Define some test functions
        auto quadratic = [](double x) { return x * x; };
        auto cubic = [](double x) { return x * x * x; };
        auto sine_approx = [](double x) { return calculus::taylor_series_sin(x, 10); };
        
        std::cout << "   Derivative of x^2 at x=2: " << calculus::derivative(quadratic, 2) << "\n";
        std::cout << "   Integral of x^2 from 0 to 3: " << calculus::simple_integrate(quadratic, 0, 3, 1000) << "\n";
        std::cout << "   Integral of x^3 from 0 to 2: " << calculus::simple_integrate(cubic, 0, 2, 1000) << "\n";
        
        // Test 6: Series expansions
        std::cout << "\n6. Series Expansions:\n";
        double x = 0.5;
        std::cout << "   Taylor series sin(" << x << ") ≈ " << calculus::taylor_series_sin(x, 15) << "\n";
        std::cout << "   Standard library sin(" << x << ") = " << std::sin(x) << "\n";
        std::cout << "   Taylor series cos(" << x << ") ≈ " << calculus::taylor_series_cos(x, 15) << "\n";
        std::cout << "   Standard library cos(" << x << ") = " << std::cos(x) << "\n";
        
        // Test 7: Root finding
        std::cout << "\n7. Root Finding:\n";
        auto parabola = [](double x) { return x * x - 4; };  // Roots at ±2
        
        try {
            double root = calculus::bisection_method(parabola, 1, 3);
            std::cout << "   Root of x^2 - 4 = 0 (between 1 and 3): " << root << "\n";
        } catch (const std::exception& e) {
            std::cout << "   Root finding error: " << e.what() << "\n";
        }
        
        // Test 8: Calculator class
        std::cout << "\n8. Calculator Class:\n";
        Calculator calc(true);  // Enable verbose logging
        calc.reset();
        calc.add(10);
        calc.multiply_by(3);
        calc.subtract(5);
        calc.divide_by(5);
        calc.power(2);
        std::cout << "   Calculator final result: " << calc.result() << "\n";
        
        // Test 9: Matrix operations
        std::cout << "\n9. Matrix Operations:\n";
        algebra::Matrix2x2 m1(1, 2, 3, 4);
        algebra::Matrix2x2 m2(2, 0, 1, 3);
        
        std::cout << "   Matrix m1 determinant: " << m1.determinant() << "\n";
        std::cout << "   Matrix m2 determinant: " << m2.determinant() << "\n";
        
        algebra::Matrix2x2 m3 = m1.multiply(m2);
        std::cout << "   m1 * m2 = [[" << m3.get(0,0) << ", " << m3.get(0,1) << "], ["
                  << m3.get(1,0) << ", " << m3.get(1,1) << "]]\n";
        
        // Test 10: Polynomial operations
        std::cout << "\n10. Polynomial Operations:\n";
        std::vector<double> coeffs = {1, -2, 1};  // x^2 - 2x + 1 = (x-1)^2
        algebra::Polynomial poly(coeffs);
        
        std::cout << "   Polynomial p(x) = x^2 - 2x + 1\n";
        std::cout << "   p(0) = " << poly.evaluate(0) << "\n";
        std::cout << "   p(1) = " << poly.evaluate(1) << "\n";
        std::cout << "   p(2) = " << poly.evaluate(2) << "\n";
        
        algebra::Polynomial derivative_poly = poly.derivative();
        std::cout << "   p'(1) = " << derivative_poly.evaluate(1) << "\n";
        
        // Test 11: Cross-partition functions
        std::cout << "\n11. Cross-Partition Functions:\n";
        std::cout << "   Sphere volume (r=5): " << calculate_sphere_volume(5) << "\n";
        std::cout << "   Circle area via integration (r=3): " << calculate_circle_area_integral(3) << "\n";
        std::cout << "   Direct circle area (r=3): " << geometry::circle_area(3) << "\n";
        
        // Test 12: Comprehensive demonstration
        std::cout << "\n12. Comprehensive Demonstration:\n";
        demonstrate_all_partitions();
        
        std::cout << "\n=== All tests completed successfully! ===\n";
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
    
    return 0;
}