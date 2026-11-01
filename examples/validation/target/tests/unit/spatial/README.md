# spatial unit tests (worker-owned)

The worker adds tests here and registers them in `CMakeLists.txt` with label `unit`:

- constant state gives zero residual;
- periodic wrap-around uses the last cell as the left neighbour of cell 0;
- `max_stable_dt` matches `dx / |speed|`;
- residual scales linearly with the advection speed.
