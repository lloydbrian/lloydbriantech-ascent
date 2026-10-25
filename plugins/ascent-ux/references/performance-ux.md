# Performance UX

What the user feels as speed. `ux-review` rates it only when there is evidence: a budget in the contract, plus Lighthouse output or field data. Otherwise it reports one Low line, "Core Web Vitals unmeasured".

## Core Web Vitals (good thresholds at the 75th percentile of page loads)

| Metric | Measures | Good | Poor |
|---|---|---|---|
| LCP, Largest Contentful Paint | loading: when the main content is visible | ≤ 2.5 s | > 4.0 s |
| INP, Interaction to Next Paint (replaced FID in March 2024) | responsiveness: delay from a tap or key to the next frame | ≤ 200 ms | > 500 ms |
| CLS, Cumulative Layout Shift | visual stability: unexpected movement | ≤ 0.1 | > 0.25 |

Between good and poor is "needs improvement". Only "poor" against a stated budget is Medium (the `ux-review` severity table).

## Evidence, best first

1. **Field data:** the Chrome UX Report or PageSpeed Insights "real users" section, or a RUM tool (for example the `web-vitals` library sending to analytics). It reflects real devices and networks.
2. **Lab data:** Lighthouse (`npx lighthouse <url> --only-categories=performance --output=json`, run by the operator) or Lighthouse CI results in the repository. It is repeatable, but it is one device and one network.
3. **Static signals**, reported as observations only:
   - page weight against `ux.performance_budget.page_kb`
   - images with no `width` and `height` (CLS)
   - render-blocking scripts in `<head>` without `defer`
   - web fonts without `font-display`
   - long lists rendered all at once

## Budgets in the contract

```yaml
performance_budget: { lcp_ms: 2500, inp_ms: 200, cls: 0.1, page_kb: 150 }
```

When the budget is missing, the lens is unmeasured, never met.
