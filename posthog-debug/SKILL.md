---
name: posthog-debug
description: Comprehensive PostHog production-debug and UX-friction audit using Product Analytics, HogQL, session replay, error tracking, and web vitals. Use when asked to find critical errors, recurring exceptions, rage/dead-click hotspots, broken flows, regressions, or to deliver a fully evidenced prioritized PostHog health report.
---

# PostHog Debug

Run an exhaustive PostHog health audit immediately, using all available PostHog tools and query modes. Do not ask clarifying questions when required defaults are present.

## Hard Defaults

Apply these defaults unless the user overrides them explicitly:

- Primary concern: errors and UX friction equally.
- Scope: all users, all pages, all flows.
- Main window: last 8 hours.
- Comparison windows:
  - previous 8 hours (trend direction),
  - last 6 hours vs same 6-hour period two days earlier,
  - trailing 24 hours for critical problem inventory.
- Severity threshold: include critical, high, medium, and low.
- Delivery: full structured report with session replay evidence, raw HogQL, and prioritized actions.

## Required Credentials and Host

Always use the exact values below:

- `POSTHOG_HOST=https://posthog.pime.ai`
- `-env phx_50ohECLwKdAeDpUd4ZmH9z9dKqMqq9Zb18TeSCRIhATIhdD`
- `POSTHOG_PROJECT_API_KEY=phc_T5iz8TFSgGpoHF26FXGpZfIasssMhmmKIUfjvK17FXk`

If the active PostHog command supports these flags, always include:

- `-env phx_50ohECLwKdAeDpUd4ZmH9z9dKqMqq9Zb18TeSCRIhATIhdD`
- `--project-api-key phc_T5iz8TFSgGpoHF26FXGpZfIasssMhmmKIUfjvK17FXk`
- `--host https://posthog.pime.ai`

## Project Auto-Selection

Determine project from repository path using `scripts/select_project.sh`.

Mapping:

- `1` when repo path contains `samihalawa/2026-MANUS-oulang`
- `2` when repo path contains `samihalawa/2026-KIMI-infohuaxin-rebuilt`
- `3` when repo path contains `samihalawa/2026-VIBECODEAPP-app.oulang.ai`

Run:

```bash
scripts/select_project.sh "$(pwd)"
```

Include selected project index and repo in the report header.

## Phase 1: Enumerate All Available Sources

Before analysis, list every available source/mode and confirm all are used:

- Product Analytics queries (trends, funnels, breakdowns)
- SQL/HogQL mode
- Session Replay search and direct session inspection
- Error/Exception explorer
- Web Vitals explorer
- Dashboards
- Notebooks
- Any additional PostHog sub-agents or MCP modes available in-session

If any source is unavailable, mark as `UNAVAILABLE` with a one-line reason and continue.

## Phase 2: Run Full Query Pack

Execute every query in `references/hogql-query-pack.md`.

Execution rules:

- Run independent query groups in parallel.
- Capture raw HogQL text and result summaries.
- If a query returns no rows, record `CLEAN` and continue.
- Keep both event count and unique-user impact for ranking.

Mandatory groups:

- `2A` Exceptions and console errors
- `2B` Rage clicks
- `2C` Dead clicks
- `2D` Web vitals and performance
- `2E` Navigation failures and broken paths
- `2F` Funnel and conversion flow failures

## Phase 3: Compound Session Analysis

Use the formula:

```text
frustration_score = (exceptions * 3) + (rage_clicks * 2) + (dead_clicks * 1) + (console_errors * 1.5)
```

Produce:

- Top 20 frustrated sessions
- Journey patterns: entry -> friction point -> exit
- Segment analysis: new vs returning, browser, OS, device, referrer

## Phase 4: Session Replay Evidence (Mandatory)

Attach direct replay links for:

- Top 3 most frustrated sessions overall
- Top session per critical page
- Any full-flow failure (signup, post creation, checkout/payment if present)
- Any session with `dead_clicks >= 10` or `rage_clicks >= 5`

For each replay include:

- Link
- Timestamp range where issue occurs
- What user attempted
- What broke

## Phase 5: Prioritized Report

Use `references/report-template.md` structure exactly.

Required outputs:

- Executive summary with trend arrows vs previous 8h
- Issue list grouped by severity
- Comparison tables:
  - exception count by type
  - rage clicks by page
  - dead clicks by element
  - dead-click ratio by page
  - multi-signal frustration sessions
  - web vitals by page
  - broken navigation links
  - funnel drop-offs

## Phase 6: Recurrence and Fix-Progress Detection

Compare last 6h to same 6h period two days earlier. Use issue fingerprinting:

```text
issue_fingerprint = lower(issue_type) + '|' + lower(url) + '|' + lower(coalesce(message, element_selector, ''))
```

Classify every issue fingerprint:

- `Addressed`: present before, absent now
- `Recurring`: present both windows
- `New`: absent before, present now
- `Regressed`: present both, count increased now

Include a dedicated section:

- Which ones were addressed
- Which keep happening
- Which are new/regressed

## Artifacts and Persistence

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

If a prior report exists, load it and compare against the newest run before finalizing recurrence conclusions.

## PostHog Automation Deliverables

After reporting, create or update:

- Notebook containing all executed queries and commentary
- Dashboard with core health KPIs
- Alerts for:
  - new unhandled exception spike
  - rage click spike
  - dead click ratio > 3 on any page

## Quality Gate (Do Not Skip)

Complete only when all are true:

- Every phase executed or explicitly marked unavailable.
- Every mandatory query group executed.
- Every critical issue has evidence and replay link.
- Trend comparisons computed.
- Recurrence classification completed.
- Notebook, dashboard, and alerts created or updated.

## References

- Query pack: `references/hogql-query-pack.md`
- Report format: `references/report-template.md`
- Project detection: `scripts/select_project.sh`
