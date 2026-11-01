#include "core/comm.hpp"
#include "core/field.hpp"
#include "core/mesh.hpp"

#include <cmath>
#include <iostream>

namespace {
int failures = 0;
void check(bool ok, const char* what) {
  if (!ok) { std::cerr << "FAIL: " << what << "\n"; ++failures; }
}
}  // namespace

int main() {
  cfd::Field a(3), b(3);
  a.data()[0] = 1.0; a.data()[1] = 2.0; a.data()[2] = 3.0;
  b.data()[0] = 0.5; b.data()[1] = -1.0; b.data()[2] = 2.0;
  a.axpy(2.0, b);
  check(std::abs(a.data()[2] - 7.0) < 1e-12, "axpy");
  check(std::abs(a.norm2() - std::sqrt(53.0)) < 1e-12, "norm2");
  cfd::Field c = a.like();
  check(c.size() == a.size(), "like");
  cfd::Mesh mesh(4, 0.25, true);
  check(mesh.cellCount() == 4 && mesh.periodic(0) && !mesh.periodic(1), "mesh");
  if (failures == 0) { std::cout << "core_test: ok\n"; return 0; }
  return 1;
}
