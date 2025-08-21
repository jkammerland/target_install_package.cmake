// Module partition implementation unit (internal utilities)
module;

// Global module fragment - includes must go here
#include <iostream>
#include <string>
#include <cmath>
#include <chrono>
#include <iomanip>
#include <sstream>

module math:internal;

// This partition contains internal implementation details
// Functions here are available to other partitions but not exported to consumers

namespace internal {
    
    // Internal logging functionality
    void log_operation(const std::string& operation, double operand1, double operand2, double result) {
        std::cout << "[MATH] " << operation << "(" << operand1;
        if (operand2 != 0.0 || operation == "add" || operation == "subtract" || 
            operation == "multiply" || operation == "divide" || operation == "power") {
            std::cout << ", " << operand2;
        }
        std::cout << ") = " << result << "\n";
    }
    
    void log_message(const std::string& message) {
        std::cout << "[MATH] " << message << "\n";
    }
    
    void log_error(const std::string& error_message) {
        std::cerr << "[MATH ERROR] " << error_message << "\n";
    }
    
    // Internal validation functions
    bool is_valid_number(double x) {
        return !std::isnan(x) && !std::isinf(x);
    }
    
    bool is_zero(double x, double epsilon = 1e-15) {
        return std::abs(x) < epsilon;
    }
    
    bool are_equal(double a, double b, double epsilon = 1e-15) {
        return std::abs(a - b) < epsilon;
    }
    
    void validate_non_negative(double value, const std::string& parameter_name) {
        if (value < 0) {
            throw std::invalid_argument(parameter_name + " cannot be negative: " + std::to_string(value));
        }
    }
    
    void validate_positive(double value, const std::string& parameter_name) {
        if (value <= 0) {
            throw std::invalid_argument(parameter_name + " must be positive: " + std::to_string(value));
        }
    }
    
    void validate_range(double value, double min_val, double max_val, const std::string& parameter_name) {
        if (value < min_val || value > max_val) {
            throw std::out_of_range(parameter_name + " must be between " + 
                                  std::to_string(min_val) + " and " + std::to_string(max_val) + 
                                  ", got: " + std::to_string(value));
        }
    }
    
    // Performance measurement utilities
    class Timer {
    private:
        std::chrono::high_resolution_clock::time_point start_time;
        std::string operation_name;
        
    public:
        Timer(const std::string& name) : operation_name(name) {
            start_time = std::chrono::high_resolution_clock::now();
        }
        
        ~Timer() {
            auto end_time = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
            log_message("Performance: " + operation_name + " took " + std::to_string(duration.count()) + " μs");
        }
    };
    
    // Memory and resource tracking
    class MemoryTracker {
    private:
        static size_t allocation_count;
        static size_t total_allocated;
        
    public:
        static void record_allocation(size_t bytes) {
            allocation_count++;
            total_allocated += bytes;
        }
        
        static void record_deallocation(size_t bytes) {
            if (total_allocated >= bytes) {
                total_allocated -= bytes;
            }
        }
        
        static void report_usage() {
            log_message("Memory usage: " + std::to_string(allocation_count) + 
                       " allocations, " + std::to_string(total_allocated) + " bytes total");
        }
        
        static size_t get_allocation_count() { return allocation_count; }
        static size_t get_total_allocated() { return total_allocated; }
    };
    
    // Initialize static members
    size_t MemoryTracker::allocation_count = 0;
    size_t MemoryTracker::total_allocated = 0;
    
    // Mathematical utilities for internal use
    double clamp(double value, double min_val, double max_val) {
        if (value < min_val) return min_val;
        if (value > max_val) return max_val;
        return value;
    }
    
    double lerp(double a, double b, double t) {
        return a + t * (b - a);
    }
    
    double smoothstep(double edge0, double edge1, double x) {
        double t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
    }
    
    // Internal computation helpers
    double fast_inverse_sqrt(double number) {
        // Approximation of 1/sqrt(x) using bit manipulation
        // Note: This is for educational purposes; std::sqrt is more accurate
        if (number <= 0) {
            throw std::invalid_argument("fast_inverse_sqrt requires positive input");
        }
        
        // For simplicity, just use standard library
        return 1.0 / std::sqrt(number);
    }
    
    double factorial_helper(int n) {
        if (n < 0) {
            throw std::invalid_argument("Factorial not defined for negative numbers");
        }
        if (n == 0 || n == 1) {
            return 1.0;
        }
        
        double result = 1.0;
        for (int i = 2; i <= n; ++i) {
            result *= i;
        }
        return result;
    }
    
    // String formatting utilities for mathematical output
    std::string format_number(double value, int precision = 6) {
        std::ostringstream stream;
        stream << std::fixed << std::setprecision(precision) << value;
        return stream.str();
    }
    
    std::string format_scientific(double value, int precision = 3) {
        std::ostringstream stream;
        stream << std::scientific << std::setprecision(precision) << value;
        return stream.str();
    }
    
    std::string format_percentage(double value, int precision = 2) {
        std::ostringstream stream;
        stream << std::fixed << std::setprecision(precision) << (value * 100.0) << "%";
        return stream.str();
    }
    
    // Error handling and diagnostics
    class ErrorCollector {
    private:
        static std::vector<std::string> errors;
        static std::vector<std::string> warnings;
        
    public:
        static void add_error(const std::string& error) {
            errors.push_back(error);
            log_error(error);
        }
        
        static void add_warning(const std::string& warning) {
            warnings.push_back(warning);
            log_message("WARNING: " + warning);
        }
        
        static void clear_all() {
            errors.clear();
            warnings.clear();
        }
        
        static const std::vector<std::string>& get_errors() { return errors; }
        static const std::vector<std::string>& get_warnings() { return warnings; }
        
        static bool has_errors() { return !errors.empty(); }
        static bool has_warnings() { return !warnings.empty(); }
        
        static void report_all() {
            if (has_errors()) {
                log_message("=== ERRORS ===");
                for (const auto& error : errors) {
                    log_error(error);
                }
            }
            
            if (has_warnings()) {
                log_message("=== WARNINGS ===");
                for (const auto& warning : warnings) {
                    log_message("WARNING: " + warning);
                }
            }
            
            if (!has_errors() && !has_warnings()) {
                log_message("No errors or warnings recorded");
            }
        }
    };
    
    // Initialize static members
    std::vector<std::string> ErrorCollector::errors;
    std::vector<std::string> ErrorCollector::warnings;
    
    // Debug utilities
    void dump_call_stack(const std::string& context) {
        log_message("=== CALL STACK DUMP: " + context + " ===");
        // In a real implementation, you would capture the actual call stack
        log_message("Context: " + context);
        log_message("=====================================");
    }
    
    void trace_computation(const std::string& operation, double input, double output) {
        log_message("TRACE: " + operation + "(" + format_number(input) + ") -> " + format_number(output));
    }
    
    // Configuration management for internal behavior
    struct InternalConfig {
        bool enable_logging = false;
        bool enable_performance_tracking = false;
        bool enable_memory_tracking = false;
        bool enable_error_collection = true;
        double numerical_tolerance = 1e-15;
        int default_integration_steps = 1000;
    };
    
    static InternalConfig config;
    
    void set_config(const InternalConfig& new_config) {
        config = new_config;
        if (config.enable_logging) {
            log_message("Internal configuration updated");
        }
    }
    
    const InternalConfig& get_config() {
        return config;
    }
    
    // Conditional logging based on configuration
    void conditional_log(const std::string& message) {
        if (config.enable_logging) {
            log_message(message);
        }
    }
    
    void conditional_trace(const std::string& operation, double input, double output) {
        if (config.enable_logging) {
            trace_computation(operation, input, output);
        }
    }
}

// Helper macros for internal use (not exported)
#define MATH_INTERNAL_TIMER(name) internal::Timer _timer(name)
#define MATH_INTERNAL_LOG(msg) internal::conditional_log(msg)
#define MATH_INTERNAL_TRACE(op, in, out) internal::conditional_trace(op, in, out)