# Core API Contract — cfd-mini v0.1 (frozen)

`core/` is human-maintained and read-only for agents. This is the minimum surface modules may use.

```cpp
namespace cfd {

class Field {
public:
  double* data();
  const double* data() const;
  std::size_t size() const;

  Field like() const;                    // same layout, uninitialized
  void copy(const Field& other);
  void axpy(double a, const Field& x);   // this += a*x
  double norm2() const;
};

class Mesh {
public:
  int dim() const;
  int nx() const;
  int ny() const;
  int nz() const;
  double dx() const;
  double dy() const;
  double dz() const;
  bool periodic(int axis) const;
  std::size_t cellCount() const;
  std::size_t ghostWidth() const;
};

class Comm {
public:
  void haloExchange(Field& field) const;
  double allreduceMin(double value) const;
  double allreduceSum(double value) const;
};

} // namespace cfd
```

Requirements:

- `Field` owns its storage; `like()` is the only allocation helper modules need.
- `Mesh` is read-only geometry; unsupported dimensions return 1.
- `Comm` is a no-op in serial mode; MPI is a later RFC.
- `residual()` must not mutate `U`; halo exchange writes only ghost cells of a dedicated work field or an explicitly documented buffer.
- `max_stable_dt()` is a local suggestion; the time integrator reduces it through `Comm`.
