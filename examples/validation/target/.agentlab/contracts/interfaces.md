# Module Interface Contract (frozen for the validation target)

```cpp
namespace cfd {
class ISpatialOperator {
public:
  virtual ~ISpatialOperator() = default;
  virtual void residual(const Field& U, double t, Field& R) const = 0;
  virtual double max_stable_dt(const Field& U, double t) const = 0;
};
}
```

## Semantics

- The caller fills the ghost layers before calling `residual`; the operator must not modify `U`.
- `R` has the same layout as `U`; only interior cells are written.
- Sign convention: `dU/dt = R(U, t)`, so for `u_t + a*u_x = 0` with `a > 0`,
  the first-order upwind residual is `R_i = -a * (U_i - U_{i-1}) / dx`.
- `max_stable_dt` returns the local CFL=1 limit, `dx / |a|` for this scheme.
- `Comm` is a serial no-op; halo exchange for periodic boundaries is implicit in the layout.
