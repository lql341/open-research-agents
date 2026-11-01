#pragma once

#include "core/comm.hpp"
#include "core/field.hpp"
#include "modules/spatial/spatial.hpp"

namespace cfd {

class ITimeIntegrator {
public:
  virtual ~ITimeIntegrator() = default;

  // Advance U in place, update t, and use comm for global dt reduction.
  virtual void advance(Field& U, double& t, double dt,
                       const ISpatialOperator& L, Comm& comm) = 0;

  virtual int order() const = 0;
};

}  // namespace cfd
