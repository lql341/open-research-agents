// MMS check for the first-order upwind residual (human-owned, agents must not edit).
// Exact solution u(x,t) = sin(2*pi*(x - a*t)) of u_t + a*u_x = 0.
// The scheme must approach R = -a*u_x with first order in h.
#include "core/field.hpp"
#include "core/mesh.hpp"
#include "modules/spatial/upwind.hpp"

#include <cmath>
#include <cstdio>
#include <stdexcept>

namespace {
constexpr double A = 1.0;   // advection speed
constexpr double T = 0.3;   // evaluation time

double exact(double x, double t) { return std::sin(2.0 * M_PI * (x - A * t)); }
double exactDx(double x, double t) { return 2.0 * M_PI * std::cos(2.0 * M_PI * (x - A * t)); }

double l2Error(int n) {
  const double h = 1.0 / n;
  cfd::Mesh mesh(n, h, true);
  const std::size_t g = mesh.ghostWidth();
  cfd::Field u(n + 2 * g);
  // Fill cells and the periodic ghost layers from the exact solution.
  for (int i = -1; i <= n; ++i) {
    const double x = (i + 0.5) * h;
    u.data()[static_cast<std::size_t>(i) + g] = exact(x, T);
  }
  cfd::Field r(u.size());
  cfd::UpwindSpatial op(mesh, A);
  op.residual(u, T, r);

  double sum = 0.0;
  for (int i = 0; i < n; ++i) {
    const double x = (i + 0.5) * h;
    const double analytic = -A * exactDx(x, T);
    const double diff = r.data()[static_cast<std::size_t>(i) + g] - analytic;
    sum += diff * diff;
  }
  return std::sqrt(sum / n);
}
}  // namespace

int main() {
  try {
    const double e1 = l2Error(40);
    const double e2 = l2Error(80);
    if (!std::isfinite(e1) || !std::isfinite(e2) || e1 <= 0.0 || e2 <= 0.0) {
      std::fprintf(stderr, "FAIL: invalid residual norm e1=%g e2=%g\n", e1, e2);
      return 1;
    }
    const double order = std::log2(e1 / e2);
    std::printf("case=mms-advection-1d\n");
    std::printf("n=40 l2=%.6e\n", e1);
    std::printf("n=80 l2=%.6e\n", e2);
    std::printf("observed_order=%.4f\n", order);
    if (order < 0.85 || order > 1.15) {
      std::fprintf(stderr, "FAIL: expected order 1, observed %.4f\n", order);
      return 1;
    }
    std::printf("PASS\n");
    return 0;
  } catch (const std::logic_error& error) {
    std::printf("UNVERIFIED: %s\n", error.what());
    return 2;
  }
}
