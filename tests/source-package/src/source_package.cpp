#include "source_package/source_package.hpp"

int source_package_generated_offset();

namespace source_package {

int add(int lhs, int rhs) {
  return lhs + rhs + source_package_generated_offset() + selected_platform_bonus();
}

}
