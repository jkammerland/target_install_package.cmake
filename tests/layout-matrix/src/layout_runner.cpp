#include "layout/layout.hpp"

int layout_archive_value();

int main() {
  return (layout_archive_value() == 11 && layout_dynamic_value() == 7) ? 0 : 1;
}
