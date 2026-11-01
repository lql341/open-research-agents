#include "modules/spatial/upwind.hpp"

#include <stdexcept>

namespace cfd {

UpwindSpatial::UpwindSpatial(const Mesh& mesh, double speed)
    : mesh_(mesh), speed_(speed) {}

void UpwindSpatial::residual(const Field&, double, Field&) const {
  throw std::logic_error("S1 not implemented: first-order upwind residual");
}

double UpwindSpatial::max_stable_dt(const Field&, double) const {
  throw std::logic_error("S1 not implemented: max_stable_dt");
}

}  // namespace cfd
