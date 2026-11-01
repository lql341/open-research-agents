#pragma once

#include "core/field.hpp"

namespace cfd {

class Comm {
public:
  void haloExchange(Field&) const {}
  double allreduceMin(double value) const { return value; }
  double allreduceSum(double value) const { return value; }
};

}  // namespace cfd
