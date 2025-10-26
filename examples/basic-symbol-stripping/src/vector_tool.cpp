#include "vector_math.h"

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string_view>
#include <vector>

namespace {

[[noreturn]] void usage(std::string_view reason = {}) {
  if (!reason.empty()) {
    std::cerr << "error: " << reason << '\n';
  }
  std::cerr << "usage:\n"
            << "  vector_tool --norm <v1> <v2> ...\n"
            << "  vector_tool --dot <dim> <a1> ... <adim> <b1> ... <bdim>\n";
  std::exit(EXIT_FAILURE);
}

double parse_double(std::string_view text) {
  char* end = nullptr;
  const double value = std::strtod(text.data(), &end);
  if (end != text.data() + static_cast<std::ptrdiff_t>(text.size())) {
    usage("expected floating point value, got '" + std::string(text) + "'");
  }
  return value;
}

int parse_int(std::string_view text) {
  char* end = nullptr;
  const long value = std::strtol(text.data(), &end, 10);
  if (end != text.data() + static_cast<std::ptrdiff_t>(text.size()) || value <= 0) {
    usage("expected positive integer, got '" + std::string(text) + "'");
  }
  return static_cast<int>(value);
}

std::vector<double> parse_vector(char** begin, char** end) {
  std::vector<double> values;
  values.reserve(static_cast<std::size_t>(end - begin));
  for (auto* it = begin; it != end; ++it) {
    values.push_back(parse_double(*it));
  }
  return values;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3) {
    usage();
  }

  const std::string_view mode{argv[1]};
  if (mode == "--norm") {
    const auto values = parse_vector(argv + 2, argv + argc);
    const double result = vector_math::norm(values);
    std::cout << std::fixed << std::setprecision(4) << result << '\n';
    return EXIT_SUCCESS;
  }

  if (mode == "--dot") {
    if (argc < 4) {
      usage("missing dimension argument for --dot");
    }

    const int dimension = parse_int(argv[2]);
    const int expected_args = 3 + 2 * dimension;
    if (argc != expected_args) {
      usage("expected exactly " + std::to_string(expected_args - 3) +
            " scalars for --dot after the dimension");
    }

    auto first = parse_vector(argv + 3, argv + 3 + dimension);
    auto second = parse_vector(argv + 3 + dimension, argv + argc);
    const double result = vector_math::dot(first, second);
    std::cout << std::fixed << std::setprecision(4) << result << '\n';
    return EXIT_SUCCESS;
  }

  usage("unknown mode '" + std::string(mode) + "'");
}
