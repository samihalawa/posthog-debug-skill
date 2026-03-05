# Report Template

Use this structure exactly.

## Executive Summary

| Metric | Value | Trend vs previous 8h |
| --- | ---: | :--- |
| Total exceptions | X | ↑/↓ |
| Unhandled exceptions | X | ↑/↓ |
| Total rage clicks | X | ↑/↓ |
| Total dead clicks | X | ↑/↓ |
| Unique frustrated users | X | ↑/↓ |
| Worst page (compound score) | /path | — |
| Critical sessions (score > 10) | X | ↑/↓ |
| Pages with dead-click ratio > 3x | X | — |
| Failed key flows (signup/post/pay) | X | — |
| Worst web vital pages (LCP > 4s) | X | — |

## Tool and Source Coverage

List all available PostHog tools/modes and mark each as:

- USED
- UNAVAILABLE (include reason)

## Critical Issues (by severity)

### 🔴 CRITICAL
### 🟠 HIGH
### 🟡 MEDIUM
### 🔵 LOW

For every issue include:

| Field | Value |
| --- | --- |
| Issue | description |
| Page(s) | URLs |
| Evidence | event counts, ratios |
| Users affected | count |
| Sessions affected | count |
| Severity | 🔴/🟠/🟡/🔵 |
| Recording | replay link |
| Root cause hypothesis | likely failure |
| Suggested fix | specific action |

## Session Replay Evidence

Mandatory:

- Top 3 most frustrated sessions overall
- Top session per critical page
- Any complete flow failure session
- Any session with 10+ dead clicks or 5+ rage clicks

For each replay include:

- Link
- Timestamp where failure is visible
- User intent
- Failure observed

## Comparison Tables

Include all:

1. Exception count by type
2. Rage-click count by page
3. Dead-click count by element
4. Dead-click ratio by page
5. Sessions with multiple frustration signals
6. Web vitals by page
7. Broken navigation links/referrers
8. Funnel drop-offs by step

## Addressed vs Recurring (Last 6h vs same window 2 days ago)

Summarize:

- Addressed issues
- Recurring issues
- New issues
- Regressed issues

Include fingerprint table:

| Fingerprint | Type | URL | Detail | Current 6h | Baseline 6h | Status |
| --- | --- | --- | --- | ---: | ---: | --- |

## 24h Critical Problem Inventory

List all high-impact items from trailing 24h:

- Top exceptions
- Top rage-click elements
- Top dead-click elements
- Highest user-impact pages

## Raw Query Appendix

Paste every executed HogQL query.

## Artifacts Created

- Notebook URL
- Dashboard URL
- Alerts configured
