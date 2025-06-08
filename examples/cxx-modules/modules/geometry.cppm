module;
#include <cmath>
#include <stdexcept>

export module geometry;

import math;

export struct Point {
  double x, y;

  constexpr Point(double x = 0.0, double y = 0.0) : x(x), y(y) {}

  double magnitude() const { return math::square_root(x * x + y * y); }

  double distance_to(const Point &other) const {
    double dx = x - other.x;
    double dy = y - other.y;
    return math::square_root(dx * dx + dy * dy);
  }
};

export class Circle {
private:
  Point center_;
  double radius_;

public:
  Circle(const Point &center, double radius)
      : center_(center), radius_(radius) {
    if (radius <= 0.0) {
      throw std::invalid_argument("Radius must be positive");
    }
  }

  Circle(double x, double y, double radius) : Circle(Point(x, y), radius) {}

  const Point &center() const { return center_; }
  double radius() const { return radius_; }

  double area() const { return math::PI * radius_ * radius_; }

  double circumference() const { return 2.0 * math::PI * radius_; }

  bool contains(const Point &point) const {
    return center_.distance_to(point) <= radius_;
  }
};

export double triangle_area(const Point &a, const Point &b, const Point &c) {
  double area =
      0.5 * std::abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y));
  return area;
}