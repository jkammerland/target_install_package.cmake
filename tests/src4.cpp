#include "component/component-devel.hpp"
#include <fmt/core.h>

inline void print_component_devel(std::string_view message) {
  fmt::println("{} from component-devel", message);
}