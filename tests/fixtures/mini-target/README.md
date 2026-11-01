# mini-target

**Platform smoke-test fixture, not a CFD codebase and not the product example.**
The real target repository is OneFLOW; see `targets/oneflow/`.

This fixture exists only so `tests/platform_smoke.sh` can exercise
preflight/scope/gate/audit without touching a real solver checkout.

## Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j2
ctest --test-dir build -L unit --output-on-failure
```

## Status

- `core/`: minimal `Field`, `Mesh`, `Comm` for the fixture only.
- `modules/spatial/` and `modules/temporal/`: compile-only placeholders.
- `.agentlab/verification/`: placeholder returns `UNVERIFIED` (exit 2).

Do not extend this fixture with CFD features. Put real work in OneFLOW.
