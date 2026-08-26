#include <iostream>

#include "tip-appimage/greeting.hpp"

int main()
{
  std::cout << tip_appimage_greeting() << '\n';
  return 0;
}
