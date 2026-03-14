# Basic Interface Library

Header-only library using `target_install_package`.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Structure

```
install/
├── include/algorithms/searching.hpp
├── include/algorithms/sorting.hpp
└── share/cmake/algorithms/*.cmake
```

## Usage

```cmake
find_package(algorithms REQUIRED)
target_link_libraries(app PRIVATE Algorithms::algorithms)
```

```cpp
#include "algorithms/searching.hpp"
#include "algorithms/sorting.hpp"

std::vector<int> values{4, 1, 3, 2};
algorithms::Sorting<int>::quickSort(values);
auto index = algorithms::Searching<int>::binarySearch(values, 3);
```
