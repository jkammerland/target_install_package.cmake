// Module partition interface unit for geometry operations
module;

// Global module fragment - includes must go here
#include <cmath>
#include <stdexcept>
#include <vector>
#include <algorithm>

export module math:geometry;

// Import algebra partition to use constants and basic operations
import :algebra;

// Export geometric operations
export namespace geometry {
    
    // 2D shapes
    double circle_area(double radius) {
        if (radius < 0) {
            throw std::invalid_argument("Radius cannot be negative");
        }
        return algebra::PI * radius * radius;
    }
    
    double circle_circumference(double radius) {
        if (radius < 0) {
            throw std::invalid_argument("Radius cannot be negative");
        }
        return 2 * algebra::PI * radius;
    }
    
    double rectangle_area(double width, double height) {
        if (width < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return width * height;
    }
    
    double rectangle_perimeter(double width, double height) {
        if (width < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return 2 * (width + height);
    }
    
    double triangle_area(double base, double height) {
        if (base < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return 0.5 * base * height;
    }
    
    double triangle_area_heron(double a, double b, double c) {
        if (a <= 0 || b <= 0 || c <= 0) {
            throw std::invalid_argument("Side lengths must be positive");
        }
        if (a + b <= c || a + c <= b || b + c <= a) {
            throw std::invalid_argument("Invalid triangle sides (triangle inequality violated)");
        }
        
        double s = (a + b + c) / 2;  // semi-perimeter
        return algebra::square_root(s * (s - a) * (s - b) * (s - c));
    }
    
    // 3D shapes
    double sphere_volume(double radius) {
        if (radius < 0) {
            throw std::invalid_argument("Radius cannot be negative");
        }
        return (4.0 / 3.0) * algebra::PI * algebra::power(radius, 3);
    }
    
    double sphere_surface_area(double radius) {
        if (radius < 0) {
            throw std::invalid_argument("Radius cannot be negative");
        }
        return 4 * algebra::PI * radius * radius;
    }
    
    double cylinder_volume(double radius, double height) {
        if (radius < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return algebra::PI * radius * radius * height;
    }
    
    double cylinder_surface_area(double radius, double height) {
        if (radius < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return 2 * algebra::PI * radius * (radius + height);
    }
    
    double cone_volume(double radius, double height) {
        if (radius < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return (1.0 / 3.0) * algebra::PI * radius * radius * height;
    }
    
    double cube_volume(double side) {
        if (side < 0) {
            throw std::invalid_argument("Side length cannot be negative");
        }
        return algebra::power(side, 3);
    }
    
    double rectangular_prism_volume(double length, double width, double height) {
        if (length < 0 || width < 0 || height < 0) {
            throw std::invalid_argument("Dimensions cannot be negative");
        }
        return length * width * height;
    }
    
    // Distance calculations
    double distance_2d(double x1, double y1, double x2, double y2) {
        double dx = x2 - x1;
        double dy = y2 - y1;
        return algebra::square_root(dx * dx + dy * dy);
    }
    
    double distance_3d(double x1, double y1, double z1, double x2, double y2, double z2) {
        double dx = x2 - x1;
        double dy = y2 - y1;
        double dz = z2 - z1;
        return algebra::square_root(dx * dx + dy * dy + dz * dz);
    }
    
    // Angle calculations
    double degrees_to_radians(double degrees) {
        return degrees * algebra::PI / 180.0;
    }
    
    double radians_to_degrees(double radians) {
        return radians * 180.0 / algebra::PI;
    }
    
    // 3D point and vector classes
    class Point3D {
    private:
        double x, y, z;
        
    public:
        Point3D(double x_val, double y_val, double z_val) : x(x_val), y(y_val), z(z_val) {}
        
        double distance_to(const Point3D& other) const {
            return distance_3d(x, y, z, other.x, other.y, other.z);
        }
        
        Point3D translate(double dx, double dy, double dz) const {
            return Point3D(x + dx, y + dy, z + dz);
        }
        
        double get_x() const { return x; }
        double get_y() const { return y; }
        double get_z() const { return z; }
    };
    
    class Vector3D {
    private:
        double x, y, z;
        
    public:
        Vector3D(double x_val, double y_val, double z_val) : x(x_val), y(y_val), z(z_val) {}
        
        double magnitude() const {
            return algebra::square_root(x * x + y * y + z * z);
        }
        
        Vector3D normalize() const {
            double mag = magnitude();
            if (mag == 0.0) {
                throw std::invalid_argument("Cannot normalize zero vector");
            }
            return Vector3D(x / mag, y / mag, z / mag);
        }
        
        Vector3D add(const Vector3D& other) const {
            return Vector3D(x + other.x, y + other.y, z + other.z);
        }
        
        Vector3D subtract(const Vector3D& other) const {
            return Vector3D(x - other.x, y - other.y, z - other.z);
        }
        
        Vector3D scale(double factor) const {
            return Vector3D(x * factor, y * factor, z * factor);
        }
        
        double dot_product(const Vector3D& other) const {
            return x * other.x + y * other.y + z * other.z;
        }
        
        Vector3D cross_product(const Vector3D& other) const {
            return Vector3D(
                y * other.z - z * other.y,
                z * other.x - x * other.z,
                x * other.y - y * other.x
            );
        }
        
        double angle_with(const Vector3D& other) const {
            double dot = dot_product(other);
            double mag_product = magnitude() * other.magnitude();
            if (mag_product == 0.0) {
                throw std::invalid_argument("Cannot compute angle with zero vector");
            }
            return std::acos(std::clamp(dot / mag_product, -1.0, 1.0));
        }
        
        double get_x() const { return x; }
        double get_y() const { return y; }
        double get_z() const { return z; }
    };
    
    // Geometric transformations
    class Transform2D {
    private:
        double matrix[3][3];  // 3x3 homogeneous transformation matrix
        
    public:
        Transform2D() {
            // Initialize as identity matrix
            for (int i = 0; i < 3; ++i) {
                for (int j = 0; j < 3; ++j) {
                    matrix[i][j] = (i == j) ? 1.0 : 0.0;
                }
            }
        }
        
        static Transform2D translation(double dx, double dy) {
            Transform2D t;
            t.matrix[0][2] = dx;
            t.matrix[1][2] = dy;
            return t;
        }
        
        static Transform2D rotation(double angle_radians) {
            Transform2D t;
            double cos_a = std::cos(angle_radians);
            double sin_a = std::sin(angle_radians);
            t.matrix[0][0] = cos_a;
            t.matrix[0][1] = -sin_a;
            t.matrix[1][0] = sin_a;
            t.matrix[1][1] = cos_a;
            return t;
        }
        
        static Transform2D scaling(double sx, double sy) {
            Transform2D t;
            t.matrix[0][0] = sx;
            t.matrix[1][1] = sy;
            return t;
        }
        
        // Apply transformation to point
        Point3D apply_to_point(double x, double y) const {
            double new_x = matrix[0][0] * x + matrix[0][1] * y + matrix[0][2];
            double new_y = matrix[1][0] * x + matrix[1][1] * y + matrix[1][2];
            return Point3D(new_x, new_y, 0.0);
        }
    };
    
    // Polygon operations
    double polygon_area(const std::vector<std::pair<double, double>>& vertices) {
        if (vertices.size() < 3) {
            throw std::invalid_argument("Polygon must have at least 3 vertices");
        }
        
        double area = 0.0;
        size_t n = vertices.size();
        
        // Shoelace formula
        for (size_t i = 0; i < n; ++i) {
            size_t j = (i + 1) % n;
            area += vertices[i].first * vertices[j].second;
            area -= vertices[j].first * vertices[i].second;
        }
        
        return std::abs(area) / 2.0;
    }
}