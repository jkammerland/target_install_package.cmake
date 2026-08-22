#include <hybrid/extension.hpp>
#include <hybrid/runtime.hpp>

int hybrid_extension_value() {
  return hybrid_runtime_value() + 2;
}
