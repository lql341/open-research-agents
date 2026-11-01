#pragma once

#include <cstddef>

namespace cfd {

class Mesh {
public:
  Mesh(int nx, double dx, bool periodic = false)
      : nx_(nx), dx_(dx), periodic_(periodic) {}

  int dim() const { return 1; }
  int nx() const { return nx_; }
  int ny() const { return 1; }
  int nz() const { return 1; }
  double dx() const { return dx_; }
  double dy() const { return 1.0; }
  double dz() const { return 1.0; }
  bool periodic(int axis) const { return axis == 0 && periodic_; }
  std::size_t cellCount() const { return static_cast<std::size_t>(nx_); }
  std::size_t ghostWidth() const { return 1; }

private:
  int nx_;
  double dx_;
  bool periodic_;
};

}  // namespace cfd
