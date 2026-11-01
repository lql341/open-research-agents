# Core API Contract (frozen for the validation target)

`core/` is human-owned and read-only for agents.

```cpp
class Field {
public:
  double* data(); const double* data() const; std::size_t size() const;
  Field like() const;
  void copy(const Field&);
  void axpy(double, const Field&);
  double norm2() const;
};
class Mesh {
public:
  int dim() const; int nx() const; double dx() const;
  bool periodic(int axis) const;
  std::size_t cellCount() const; std::size_t ghostWidth() const;
};
class Comm {
public:
  void haloExchange(Field&) const;
  double allreduceMin(double) const;
  double allreduceSum(double) const;
};
```
