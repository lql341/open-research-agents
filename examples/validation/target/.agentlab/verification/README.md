# Verification (human-owned)

`verification/adv_mms.cpp` compares the residual against the analytic derivative of
`u(x,t) = sin(2*pi*(x - a*t))` at two resolutions and computes the observed order.

Exit contract of `run_all.sh`: `0` PASS, `1` FAIL, `2` UNVERIFIED (not implemented yet).

Spatial refinement: n = 40 and n = 80. First-order upwind must give order ≈ 1.
