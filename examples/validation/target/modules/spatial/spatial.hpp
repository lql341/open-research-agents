#pragma once
#include "core/field.hpp"

namespace cfd {
class ISpatialOperator {
public:
  virtual ~ISpatialOperator() = default;
  // Compute residual R = dU/dt for the advection equation; U is read-only.
  virtual void residual(const Field& U, double t, Field& R) const = 0;
  // Local stability limit (CFL=1).
  virtual double max_stable_dt(const Field& U, double t) const = 0;
};
}  // namespace cfd
