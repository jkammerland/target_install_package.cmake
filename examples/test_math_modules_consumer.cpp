import geometry;

int main() {
  Point p1{0.0, 0.0};
  Point p2{3.0, 4.0};

  const double distance = p1.distance_to(p2);
  return (distance > 4.9 && distance < 5.1) ? 0 : 1;
}
