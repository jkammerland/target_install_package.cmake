export module geometry;

import math;
import <cmath>;

// Export the geometry namespace
export namespace geometry {

// Point structure
export struct Point {
    double x, y;
    
    constexpr Point(double x = 0.0, double y = 0.0) : x(x), y(y) {}
    
    // Distance from origin
    double magnitude() const {
        return math::square_root(x * x + y * y);
    }
    
    // Distance between two points
    double distance_to(const Point& other) const {
        double dx = x - other.x;
        double dy = y - other.y;
        return math::square_root(dx * dx + dy * dy);
    }
};

// Circle class
export class Circle {
private:
    Point center_;
    double radius_;

public:
    constexpr Circle(const Point& center, double radius) 
        : center_(center), radius_(radius) {
        if (radius <= 0.0) {
            throw std::invalid_argument("Radius must be positive");
        }
    }
    
    constexpr Circle(double x, double y, double radius) 
        : Circle(Point(x, y), radius) {}
    
    // Getters
    constexpr const Point& center() const { return center_; }
    constexpr double radius() const { return radius_; }
    
    // Area calculation
    double area() const {
        return math::PI * radius_ * radius_;
    }
    
    // Circumference calculation
    double circumference() const {
        return 2.0 * math::PI * radius_;
    }
    
    // Check if a point is inside the circle
    bool contains(const Point& point) const {
        return center_.distance_to(point) <= radius_;
    }
};

// Rectangle class
export class Rectangle {
private:
    Point bottom_left_;
    double width_, height_;

public:
    constexpr Rectangle(const Point& bottom_left, double width, double height)
        : bottom_left_(bottom_left), width_(width), height_(height) {
        if (width <= 0.0 || height <= 0.0) {
            throw std::invalid_argument("Width and height must be positive");
        }
    }
    
    constexpr Rectangle(double x, double y, double width, double height)
        : Rectangle(Point(x, y), width, height) {}
    
    // Getters
    constexpr const Point& bottom_left() const { return bottom_left_; }
    constexpr double width() const { return width_; }
    constexpr double height() const { return height_; }
    
    // Area calculation
    constexpr double area() const {
        return width_ * height_;
    }
    
    // Perimeter calculation
    constexpr double perimeter() const {
        return 2.0 * (width_ + height_);
    }
    
    // Check if a point is inside the rectangle
    bool contains(const Point& point) const {
        return point.x >= bottom_left_.x && 
               point.x <= bottom_left_.x + width_ &&
               point.y >= bottom_left_.y && 
               point.y <= bottom_left_.y + height_;
    }
    
    // Get corner points
    Point top_right() const {
        return Point(bottom_left_.x + width_, bottom_left_.y + height_);
    }
};

// Utility functions
export double triangle_area(const Point& a, const Point& b, const Point& c) {
    // Using the cross product formula
    double area = 0.5 * std::abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y));
    return area;
}

export bool points_are_collinear(const Point& a, const Point& b, const Point& c) {
    // Points are collinear if the triangle area is zero (within tolerance)
    constexpr double EPSILON = 1e-10;
    return triangle_area(a, b, c) < EPSILON;
}

} // namespace geometry