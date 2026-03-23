# Report Template

Use this structure exactly, but adapt the comparison label to the chosen mode.

## Scope and Mode

- Mode: `incident` | `product` | `monetization` | `feature` | `full_audit`
- Current window: `...`
- Comparison window: `...`
- Trailing inventory window: `24h` or `7d`
- Project / repo: `...`

## Executive Summary

| Metric | Value | Trend vs comparison |
| --- | ---: | :--- |
| Total pageviews | X | ↑/↓ |
| Unique active users | X | ↑/↓ |
| Top page by views | /path | — |
| Top custom event | event_name | ↑/↓ |
| Total exceptions | X | ↑/↓ |
| Total rage clicks | X | ↑/↓ |
| Total dead clicks | X | ↑/↓ |
| Top reliability issue | issue_name | ↑/↓ |
| Key funnel completion rate | X% | ↑/↓ |
| Biggest feature change | feature_name | ↑/↓ |
| Highest-impact affected users | X | ↑/↓ |

## Tool and Source Coverage

List all available PostHog tools/modes and mark each as:

- USED
- UNAVAILABLE (include reason)

## Traffic and Adoption Snapshot

Include:

1. Top pages by views and unique users
2. Top events by volume and unique users
3. 7-day daily trend
4. Feature movement table

## Monetization and Funnel Health

Include when monetization is relevant or when the data shows payment/promote events:

1. Recharge / credits funnel
2. Banner / promote funnel
3. Drop-off step table
4. Interpretation of where discovery increases but conversion leaks

## Reliability and UX Friction

Include:

1. Exceptions and custom reliability events
2. Rage-click hotspots
3. Dead-click hotspots
4. Web vitals outliers
5. Logs correlation summary when reliability issues are elevated

## Critical Issues (by severity)

### 🔴 CRITICAL
### 🟠 HIGH
### 🟡 MEDIUM
### 🔵 LOW

For every issue include:

| Field | Value |
| --- | --- |
| Issue | description |
| Page(s) / flow | URLs or steps |
| Evidence | event counts, users, ratios |
| Users affected | count |
| Sessions affected | count |
| Severity | 🔴/🟠/🟡/🔵 |
| Recording | replay link |
| Root cause hypothesis | likely failure |
| Suggested fix | specific action |

## Session Replay Evidence

Mandatory:

- Top 3 most frustrated sessions overall
- Top broken payment or promotion session when monetization is in scope
- Top broken creation flow session when signup/post/listing is in scope
- Top session per critical page
- Any session with 10+ dead clicks or 5+ rage clicks

For each replay include:

- Link
- Timestamp where failure is visible
- User intent
- Failure observed

## Comparison Tables

Include all relevant tables:

1. Top events by count and unique users
2. Top pages by views and unique users
3. Daily trend by day
4. Feature movement by bucket
5. Payment / promote funnel drop-offs
6. Exception count by type
7. Custom reliability events by day
8. Rage-click count by page or element
9. Dead-click count by element
10. Dead-click ratio by page
11. Sessions with multiple frustration signals
12. Web vitals by page
13. Broken navigation links / referrers

## Addressed vs Recurring (Last 6h vs same window 2 days ago)

Summarize:

- Addressed issues
- Recurring issues
- New issues
- Regressed issues

Include fingerprint table:

| Fingerprint | Type | URL | Detail | Current 6h | Baseline 6h | Status |
| --- | --- | --- | --- | ---: | ---: | --- |

## Prioritized Actions

List the highest-impact fixes in strict order with:

- why it matters
- owner surface (frontend, backend, analytics, content, pricing, growth)
- expected impact

## Raw Query Appendix

Paste every executed HogQL query.

## Artifacts Created

- Notebook URL
- Dashboard URL
- Alerts configured
