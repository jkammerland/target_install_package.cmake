import source_math;

int main() {
  const bool add_ok = source_math::add(19, 23) == 42;
  const bool average_ok = source_math::average(20, 24) == 22.0;
  return add_ok && average_ok ? 0 : 1;
}
