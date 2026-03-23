---
name: posthog-debug
description: Comprehensive PostHog analysis for product analytics, conversion leakage, feature adoption, revenue friction, error spikes, logs, session replay, and UX friction. Use when asked what changed, what is broken, where users drop off, which features are declining, or to deliver a fully evidenced prioritized PostHog health report.
---

# PostHog Debug

Run a full PostHog analysis using MCP-native tools first, then drop to HogQL only where structured insights are insufficient.

Do not ask clarifying questions when required defaults are present. Start with source discovery, then choose the right analysis mode, then run comparisons with evidence.

## Tool Priority

Per the official PostHog MCP docs, prefer these tools in this order when available:

1. `event-definitions-list`, `properties-list`, `read-data-schema`
2. `query-run` for trends, funnels, and paths
3. `query-generate-hogql-from-question` to bootstrap custom analysis, then tighten the query manually
4. `list-errors`, `error-details`, `error-tracking-issues-list`
5. `logs-query` for backend or API failures that do not show up cleanly in browser-side error tracking
6. `insights-get-all`, `insight-create-from-query`, `insight-query`
7. `notebooks-*`, `dashboard-*`, `alert-*`
8. Raw HogQL from `references/hogql-query-pack.md`

Never jump straight to a generic narrative summary when the MCP can return real counts, users, steps, paths, logs, or replay evidence.

## Default Mode Selection

Choose the mode from the user request. If the request is mixed, do both the product and reliability passes.

- `incident`: error spike, broken flow, slowdown, regression, dead/rage clicks, outages
- `product`: traffic, page popularity, event usage, feature adoption, what changed
- `monetization`: checkout, recharge, credits, banners, promotion funnel, payment drop-off
- `feature`: AI, TV, games, support chat, or any named feature
- `full_audit`: broad health report across product, revenue, and friction

Default windows:

- `incident`: last 8h vs previous 8h, plus trailing 24h critical inventory
- `product`, `monetization`, `feature`, or unspecified: last 48h vs previous 48h, plus 7-day daily trend
- recurrence check: last 6h vs same 6h two days earlier

Always include both event count and unique-user impact.

## Credentials and Host

Use the real repository `.env` first when available. The root `.env` is the canonical source of truth.

Credential priority:

1. `POSTHOG_PERSONAL_API_KEY` for MCP authentication when available
2. fallback `phx_...` environment key returned by `scripts/select_project.sh`
3. use `POSTHOG_PROJECT_API_KEY` or `VITE_PUBLIC_POSTHOG_KEY` only when the active wrapper explicitly requires the project key for query context or app-side correlation

Host priority:

1. `POSTHOG_HOST`
2. `VITE_PUBLIC_POSTHOG_HOST`
3. `VITE_POSTHOG_HOST`
4. fallback host from `scripts/select_project.sh`

If the active PostHog wrapper supports flags, pass the discovered host and the correct auth key. Do not assume the project API key is the right credential for MCP auth if a personal API key is available.

## Project and Environment Detection

Resolve context with:

```bash
scripts/select_project.sh "$(pwd)"
```

This script should provide:

- repo label
- project index when known
- detected `.env` path when present
- host
- personal API key when present
- project API key when present

If the repo path is not one of the known projects, continue with env-derived values instead of aborting the analysis.

## Phase 1: Source and Schema Discovery

Before analysis, enumerate every available source and confirm all are used or marked unavailable:

- event definitions
- property definitions / data schema
- trends / funnels / paths
- HogQL / SQL mode
- session replay search and direct session inspection
- error tracking explorer
- logs explorer
- web vitals / performance
- dashboards
- notebooks
- alerts

Then run a schema and event inventory first:

- top events
- top pages
- high-volume custom events
- error-like custom events such as `api_error`, `route_loading_timeout`, `page_not_found`, `route_not_found_rendered`, `auth_error`

Never rely on `$exception` alone. If error tracking is quiet but custom error events are noisy, treat that as a real reliability problem.

## Phase 2: Run the Right Query Pack

Use `references/hogql-query-pack.md`.

Execution rules:

- Run independent query groups in parallel.
- Use structured `query-run` trends/funnels/paths before raw HogQL where possible.
- If the MCP offers natural-language query generation, use it to draft complex HogQL, then tighten it manually.
- Record raw query text and result summaries.
- If a query returns no rows, record `CLEAN` and continue.
- Rank findings by both event volume and user impact.

Mandatory groups for all non-trivial analyses:

- `0` Property discovery
- `1A` Top event inventory
- `1B` Top page inventory
- `1C` Daily trend
- `1D` Bucket comparison by domain
- `1F` Custom reliability signals
- `2F` Flow and conversion failures

Add these when relevant:

- `2A` Exceptions and console errors
- `2B` Rage clicks
- `2C` Dead clicks
- `2D` Web vitals and performance
- `2E` Navigation failures and broken paths
- `3A` Frustration score per session
- `5` Trend and recurrence windows
- `24h Critical Inventory`

## Phase 3: Product and Revenue Interpretation

For product, adoption, or monetization requests, always produce:

- top pages by views and unique users
- top custom events by volume and unique users
- 48h vs previous 48h movement for major buckets
- 7-day daily trend
- feature-specific adoption table for named features
- payment and promote funnel leakage

Specific rules:

- If recharge or checkout page views increase while completions fall, call out conversion friction explicitly.
- If feature entry events hold steady but downstream completion/use events drop, call out adoption decay or content exhaustion.
- If a feature has negligible unique-user count, classify it as low adoption even if percent change looks large.
- If monetization discovery increases but checkout completion does not, treat that as a broken or leaking funnel, not a success.

## Phase 4: Reliability, Logs, and Frustration

If the report shows custom error spikes, route timeouts, or broken flow events:

- inspect `list-errors` / `error-details`
- inspect `logs-query`
- inspect custom error event trends
- correlate with dead clicks, rage clicks, and web vitals by page

Use the formula:

```text
frustration_score = (exceptions * 3) + (rage_clicks * 2) + (dead_clicks * 1) + (console_errors * 1.5)
```

Produce:

- top frustrated sessions
- journey pattern: entry -> friction point -> exit
- segment analysis by browser, OS, device, referrer, new vs returning

## Phase 5: Session Replay Evidence

Attach direct replay links for:

- top 3 most frustrated sessions overall
- top failed payment or promotion session when monetization is in scope
- top failed signup/post/listing session when creation flows are in scope
- top session per critical page
- any session with `dead_clicks >= 10` or `rage_clicks >= 5`

For each replay include:

- link
- timestamp range where issue occurs
- what the user attempted
- what broke or where they hesitated

## Phase 6: Prioritized Report

Use `references/report-template.md`.

Required outputs:

- scope and chosen mode
- executive summary with comparison window
- traffic and adoption snapshot
- monetization and funnel health
- reliability and UX friction
- issue list grouped by severity
- feature movement table
- recurrence classification
- prioritized fixes

## Phase 7: Persistence and Automation

Save outputs under:

```text
.posthog-debug-reports/YYYY-MM-DD_HH-mm/
```

Write:

- `report.md`
- `queries.sql`
- `results-summary.json`
- `issue-fingerprints-current.csv`
- `issue-fingerprints-baseline.csv`
- `issue-diff.csv`

If a prior report exists, compare against it before finalizing recurrence conclusions.

For full audits or sustained issues, create or update:

- notebook with executed queries and commentary
- dashboard with core KPIs
- alerts for exception spikes, rage-click spikes, and broken funnel deterioration

## Quality Gate

Complete only when all are true:

- chosen mode is explicit
- every relevant source is used or marked unavailable
- baseline inventory is complete
- comparison windows are computed
- critical issues have direct evidence
- revenue or feature claims include counts and unique users
- replay evidence is attached for the highest-impact broken sessions
- logs were checked when custom reliability events are elevated

## References

- Query pack: `references/hogql-query-pack.md`
- Report format: `references/report-template.md`
- Project detection: `scripts/select_project.sh`
