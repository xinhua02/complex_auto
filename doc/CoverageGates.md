# Coverage Gates Template

Date: 2026-06-24
Scope: AXI xbar UVM (2x2 baseline)

This template defines practical coverage gates for smoke/nightly runs and a reporting format for closure tracking.

## 1. Gate Definitions

| Metric | Description | Smoke Gate | Nightly Gate |
| --- | --- | ---: | ---: |
| Route pair hit | All ingress->egress route bins hit | 100% required | 100% required |
| DECERR read hit | Per-ingress DECERR read observed | 100% required | 100% required |
| DECERR write hit | Per-ingress DECERR write observed | 100% required | 100% required |
| Same-ID cross-dst check | Per-ingress ordering check exercised | 100% required | 100% required |
| Same-ID violation count | Ordering violations detected | 0 required | 0 required |
| Regression pass rate | Seeds passed / total seeds | >= 95% | >= 98% |

## 2. Seed Policy

- Smoke profile: small deterministic seed set (default 1..10).
- Nightly profile: expanded seed set (default 1..100).
- Add periodic out-of-range spot seeds (for example 199, 299) to avoid overfitting.

## 3. Reporting Format

Copy this block into verification reports:

```text
Coverage gate summary:
- Route pair hit: <value>% (gate: <value>%)
- DECERR read hit: <value>% (gate: 100%)
- DECERR write hit: <value>% (gate: 100%)
- Same-ID check hit: <value>% (gate: 100%)
- Same-ID violations: <count> (gate: 0)
- Regression pass rate: <value>% (gate: <value>%)
```

## 4. Runbook

1. Run smoke:
   - .\scripts\run_regression.ps1 -Profile smoke
2. Run nightly:
   - .\scripts\run_regression.ps1 -Profile nightly
3. Archive generated markdown summary under axi/build/.
4. Update doc/VerificationReport.md with gate status and exceptions.

## 5. Exception Handling

- If a gate fails, open a short incident note with:
  - failing seeds
  - top error signature
  - first bad commit range
  - fix owner and ETA
- If violations are only from environment noise, document rationale and mitigation before waiving.
