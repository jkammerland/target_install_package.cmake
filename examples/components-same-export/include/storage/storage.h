#pragma once
#include <fstream>
#include <map>
#include <string>

namespace Game {
class Storage {
public:
  Storage(const std::string &filename);
  void set(const std::string &key, const std::string &value);
  std::string get(const std::string &key) const;
  void save();
  void load();

private:
  std::string filename_;
  std::map<std::string, std::string> data_;
};
} // namespace Game