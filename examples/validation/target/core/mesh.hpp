#pragma once
#include <cstddef>

namespace cfd {
class Mesh {
public:
  Mesh(int nx, double dx, bool periodic = false)
      : nx_(nx), dx_(dx), periodic_(periodic) {}
  int dim() const { return 1; }
  int nx() const { return nx_; }
  double dx() const { return dx_; }
  bool periodic(int axis) const { return axis == 0 && periodic_; }
  std::size_t cellCount() const { return static_cast<std::size_t>(nx_); }
  std::size_t ghostWidth() const { return 1; }
private:
  int nx_;
  double dx_;
  bool periodic_;
};
}  // namespace cfd
