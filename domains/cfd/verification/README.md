# Verification Cases (human-maintained; agents must not change baselines/tolerances)

| Case | Checks | Main module |
|---|---|---|
| MMS spatial convergence | Spatial order | spatial |
| ODE time convergence (mock) | Time order | temporal |
| Linear advection, periodic | Dissipation/dispersion, conservation | integration |
| Taylor-Green vortex | Low-speed viscous decay (after viscous module) | integration |
| Lid-driven cavity | Literature comparison | integration |

Each case should write `.agentlab/repro/<case>-<time>.case.json`; fields are in `repro_fields.yaml`.

`run_all.sh` is currently a placeholder. Register the first real case before enabling integration.

Exit contract: `0` PASS, `1` FAIL, `2` UNVERIFIED.
