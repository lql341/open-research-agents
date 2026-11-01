#pragma once

#include "core/mesh.hpp"
#include "modules/spatial/spatial.hpp"

namespace cfd {

class UpwindSpatial final : public ISpatialOperator {
public:
  UpwindSpatial(const Mesh& mesh, double speed);

  void residual(const Field& U, double t, Field& R) const override;
  double max_stable_dt(const Field& U, double t) const override;

private:
  const Mesh& mesh_;
  double speed_;
};

}  // namespace cfd
