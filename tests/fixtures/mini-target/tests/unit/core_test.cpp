#include "core/comm.hpp"
#include "core/field.hpp"
#include "core/mesh.hpp"

#include <cmath>
#include <iostream>

namespace {
int failures = 0;

void check(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    ++failures;
  }
}
}  // namespace

int main() {
  cfd::Field a(3);
  cfd::Field b(3);
  a.data()[0] = 1.0;
  a.data()[1] = 2.0;
  a.data()[2] = 3.0;
  b.data()[0] = 0.5;
  b.data()[1] = -1.0;
  b.data()[2] = 2.0;

  a.axpy(2.0, b);
  check(std::abs(a.data()[0] - 2.0) < 1e-12, "axpy index 0");
  check(std::abs(a.data()[1] - 0.0) < 1e-12, "axpy index 1");
  check(std::abs(a.data()[2] - 7.0) < 1e-12, "axpy index 2");
  check(std::abs(a.norm2() - std::sqrt(53.0)) < 1e-12, "norm2");

  cfd::Field c = a.like();
  check(c.size() == a.size(), "like preserves size");
  c.copy(a);
  check(std::abs(c.data()[2] - 7.0) < 1e-12, "copy");

  cfd::Mesh mesh(4, 0.25, true);
  check(mesh.dim() == 1, "mesh dim");
  check(mesh.nx() == 4, "mesh nx");
  check(mesh.cellCount() == 4, "mesh cellCount");
  check(mesh.periodic(0), "mesh periodic");
  check(!mesh.periodic(1), "mesh non-periodic axis");

  cfd::Comm comm;
  comm.haloExchange(a);
  check(comm.allreduceMin(3.0) == 3.0, "serial allreduceMin");
  check(comm.allreduceSum(4.0) == 4.0, "serial allreduceSum");

  if (failures == 0) {
    std::cout << "core_test: ok\n";
    return 0;
  }
  std::cerr << "core_test: " << failures << " failure(s)\n";
  return 1;
}
