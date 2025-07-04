#pragma once
#include <iostream>
#include <memory>
#include <vector>

namespace Graphics {
class Shape {
public:
  virtual ~Shape() = default;
  virtual void render() const = 0;
};

class Circle : public Shape {
public:
  void render() const override {
    std::cout << "Rendering Circle (dummy implementation)" << std::endl;
  }
};

class Rectangle : public Shape {
public:
  void render() const override {
    std::cout << "Rendering Rectangle (dummy implementation)" << std::endl;
  }
};

class GraphicsEngine {
public:
  void addShape(std::unique_ptr<Shape> shape) {
    shapes_.push_back(std::move(shape));
  }

  void renderAll() const {
    for (const auto &shape : shapes_) {
      shape->render();
    }
  }

private:
  std::vector<std::unique_ptr<Shape>> shapes_;
};
} // namespace Graphics
