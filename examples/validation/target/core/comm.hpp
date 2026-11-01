#pragma once
#include "core/field.hpp"

namespace cfd {
class Comm {
public:
  void haloExchange(Field&) const {}
  double allreduceMin(double v) const { return v; }
  double allreduceSum(double v) const { return v; }
};
}  // namespace cfd
