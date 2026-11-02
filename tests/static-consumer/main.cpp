#include <static2/header.h>
#include <tests/header.h>

int main() {
  return foo_static() == 42 && get_string() == "Hello from static21.0.0" ? 0 : 1;
}
