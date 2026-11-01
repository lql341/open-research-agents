#pragma once

#include "modules/temporal/temporal.hpp"

namespace cfd {

class ForwardEuler final : public ITimeIntegrator {
public:
  void advance(Field& U, double& t, double dt,
               const ISpatialOperator& L, Comm& comm) override;
  int order() const override { return 1; }
};

}  // namespace cfd
