#include "modules/temporal/forward_euler.hpp"

#include <stdexcept>

namespace cfd {

void ForwardEuler::advance(Field&, double&, double,
                           const ISpatialOperator&, Comm&) {
  throw std::logic_error("T1 not implemented: ForwardEuler::advance");
}

}  // namespace cfd
