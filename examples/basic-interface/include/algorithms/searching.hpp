#pragma once

#include <vector>
#include <optional>

namespace algorithms {

template<typename T>
class Searching {
public:
    static std::optional<size_t> linearSearch(const std::vector<T>& arr, const T& target) {
        for (size_t i = 0; i < arr.size(); ++i) {
            if (arr[i] == target) {
                return i;
            }
        }
        return std::nullopt;
    }
    
    static std::optional<size_t> binarySearch(const std::vector<T>& arr, const T& target) {
        int left = 0;
        int right = static_cast<int>(arr.size()) - 1;
        
        while (left <= right) {
            int mid = left + (right - left) / 2;
            
            if (arr[mid] == target) {
                return static_cast<size_t>(mid);
            }
            
            if (arr[mid] < target) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        
        return std::nullopt;
    }
};

} // namespace algorithms