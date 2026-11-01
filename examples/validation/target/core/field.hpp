#pragma once
#include <cmath>
#include <cstddef>
#include <stdexcept>
#include <vector>

namespace cfd {
class Field {
public:
  explicit Field(std::size_t size = 0) : data_(size, 0.0) {}
  double* data() { return data_.data(); }
  const double* data() const { return data_.data(); }
  std::size_t size() const { return data_.size(); }
  Field like() const { return Field(size()); }
  void copy(const Field& other) { check(other); data_ = other.data_; }
  void axpy(double a, const Field& x) {
    check(x);
    for (std::size_t i = 0; i < data_.size(); ++i) data_[i] += a * x.data_[i];
  }
  double norm2() const {
    double sum = 0.0;
    for (double v : data_) sum += v * v;
    return std::sqrt(sum);
  }
private:
  void check(const Field& o) const {
    if (o.size() != size()) throw std::invalid_argument("Field size mismatch");
  }
  std::vector<double> data_;
};
}  // namespace cfd
