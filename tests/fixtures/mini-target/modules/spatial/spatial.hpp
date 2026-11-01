#pragma once

#include "core/field.hpp"

namespace cfd {

class ISpatialOperator {
public:
  virtual ~ISpatialOperator() = default;

  // Compute residual R; U is read-only. Halo exchange is this operator's job.
  virtual void residual(const Field& U, double t, Field& R) const = 0;

  // Local stability limit (CFL=1); the time integrator reduces the global minimum.
  virtual double max_stable_dt(const Field& U, double t) const = 0;
};

}  // namespace cfd
