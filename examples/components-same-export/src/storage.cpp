#include "storage/storage.h"
#include <iomanip>
#include <sstream>

namespace Game {
Storage::Storage(const std::string &filename) : filename_(filename) {}

void Storage::set(const std::string &key, const std::string &value) {
  data_[key] = value;
}

std::string Storage::get(const std::string &key) const {
  auto it = data_.find(key);
  return (it != data_.end()) ? it->second : "";
}

void Storage::save() {
  std::ofstream file(filename_);
  if (!file)
    return;

  for (const auto &[key, value] : data_) {
    file << key << ":" << value << "\n";
  }
}

void Storage::load() {
  std::ifstream file(filename_);
  if (!file)
    return;

  data_.clear();
  std::string line;
  while (std::getline(file, line)) {
    size_t colonPos = line.find(':');
    if (colonPos != std::string::npos) {
      std::string key = line.substr(0, colonPos);
      std::string value = line.substr(colonPos + 1);
      data_[key] = value;
    }
  }
}
} // namespace Game