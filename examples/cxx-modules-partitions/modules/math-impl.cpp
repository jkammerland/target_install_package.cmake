// Module implementation unit for internal functions
module;

#include <iostream>
#include <string>

module math;

// Internal implementation function (not exported)
void log_calculator_operation(const std::string& operation, double operand1, double operand2, double result) {
    std::cout << "[Calculator] " << operation << "(" << operand1 << ", " << operand2 << ") = " << result << "\n";
}