# HogQL Query Pack

Run all queries with these time windows bound before execution:

- `CURRENT_8H_START = now() - INTERVAL 8 HOUR`
- `PREV_8H_START = now() - INTERVAL 16 HOUR`
- `PREV_8H_END = now() - INTERVAL 8 HOUR`
- `CURRENT_6H_START = now() - INTERVAL 6 HOUR`
- `BASELINE_6H_START = now() - INTERVAL 54 HOUR`
- `BASELINE_6H_END = now() - INTERVAL 48 HOUR`
- `CURRENT_24H_START = now() - INTERVAL 24 HOUR`

## 0) Property Discovery (Run First)

```sql
SELECT key, count() AS events
FROM (
  SELECT arrayJoin(mapKeys(properties)) AS key
  FROM events
  WHERE timestamp >= now() - INTERVAL 8 HOUR
)
GROUP BY key
ORDER BY events DESC
LIMIT 300;
```

## 2A) Exceptions and Errors

### A1. All exceptions in current 8h

```sql
SELECT
  coalesce(properties.$exception_message, '(missing)') AS exception_message,
  coalesce(properties.$exception_type, '(missing)') AS exception_type,
  toString(coalesce(properties.$exception_handled, 'unknown')) AS handled,
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$browser, '(missing)') AS browser,
  coalesce(properties.$os, '(missing)') AS os,
  count() AS events,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$exception'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY exception_message, exception_type, handled, url, browser, os
ORDER BY events DESC, users DESC
LIMIT 500;
```

### A2. Handled vs unhandled exceptions trend (current 8h vs previous 8h)

```sql
SELECT
  period,
  handled,
  count() AS events,
  uniq(distinct_id) AS users
FROM (
  SELECT
    if(timestamp >= now() - INTERVAL 8 HOUR, 'current_8h', 'previous_8h') AS period,
    toString(coalesce(properties.$exception_handled, 'unknown')) AS handled
  FROM events
  WHERE event = '$exception'
    AND timestamp >= now() - INTERVAL 16 HOUR
)
GROUP BY period, handled
ORDER BY period, events DESC;
```

### A3. Error cascades (sessions with multiple exception types)

```sql
SELECT
  coalesce(properties.$session_id, '') AS session_id,
  uniq(coalesce(properties.$exception_type, coalesce(properties.$exception_message, 'unknown'))) AS unique_exception_signatures,
  count() AS total_exceptions,
  uniq(distinct_id) AS users,
  min(timestamp) AS first_seen,
  max(timestamp) AS last_seen
FROM events
WHERE event = '$exception'
  AND timestamp >= now() - INTERVAL 8 HOUR
  AND coalesce(properties.$session_id, '') != ''
GROUP BY session_id
HAVING unique_exception_signatures >= 2
ORDER BY unique_exception_signatures DESC, total_exceptions DESC
LIMIT 200;
```

### A4. Console errors

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$browser, '(missing)') AS browser,
  coalesce(properties.$os, '(missing)') AS os,
  count() AS console_error_events,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$console_log'
  AND coalesce(properties.$console_log_level, '') = 'error'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, browser, os
ORDER BY console_error_events DESC
LIMIT 300;
```

### A5. Pages with both exceptions and rage clicks in same sessions

```sql
WITH exceptions AS (
  SELECT
    coalesce(properties.$session_id, '') AS session_id,
    coalesce(properties.$current_url, '(missing)') AS url,
    count() AS exception_count
  FROM events
  WHERE event = '$exception'
    AND timestamp >= now() - INTERVAL 8 HOUR
    AND coalesce(properties.$session_id, '') != ''
  GROUP BY session_id, url
),
rage AS (
  SELECT
    coalesce(properties.$session_id, '') AS session_id,
    coalesce(properties.$current_url, '(missing)') AS url,
    count() AS rage_count
  FROM events
  WHERE event = '$rageclick'
    AND timestamp >= now() - INTERVAL 8 HOUR
    AND coalesce(properties.$session_id, '') != ''
  GROUP BY session_id, url
)
SELECT
  e.url,
  sum(e.exception_count) AS exceptions,
  sum(r.rage_count) AS rage_clicks,
  uniq(e.session_id) AS sessions
FROM exceptions e
INNER JOIN rage r ON e.session_id = r.session_id AND e.url = r.url
GROUP BY e.url
ORDER BY (exceptions + rage_clicks) DESC
LIMIT 200;
```

## 2B) Rage Clicks

### B1. Rage clicks by page and element

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$el_text, '(no text)') AS element_text,
  coalesce(properties.$el_tag_name, '(no tag)') AS element_tag,
  coalesce(properties.$el_selector, '(no selector)') AS element_selector,
  count() AS rage_clicks,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$rageclick'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, element_text, element_tag, element_selector
ORDER BY rage_clicks DESC, users DESC
LIMIT 500;
```

### B2. Rage-click clusters (>=3 in same session)

```sql
SELECT
  coalesce(properties.$session_id, '') AS session_id,
  count() AS rage_clicks,
  uniq(coalesce(properties.$current_url, '(missing)')) AS pages,
  min(timestamp) AS first_seen,
  max(timestamp) AS last_seen
FROM events
WHERE event = '$rageclick'
  AND timestamp >= now() - INTERVAL 8 HOUR
  AND coalesce(properties.$session_id, '') != ''
GROUP BY session_id
HAVING rage_clicks >= 3
ORDER BY rage_clicks DESC
LIMIT 300;
```

## 2C) Dead Clicks

### C1. Dead clicks by page and element

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$el_text, '(no text)') AS element_text,
  coalesce(properties.$el_selector, '(no selector)') AS element_selector,
  avg(toFloat64OrZero(coalesce(properties.$dead_click_scroll_delay_ms, 0))) AS avg_scroll_delay_ms,
  avg(toFloat64OrZero(coalesce(properties.$dead_click_mutation_delay_ms, 0))) AS avg_mutation_delay_ms,
  count() AS dead_clicks,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$dead_click'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, element_text, element_selector
ORDER BY dead_clicks DESC
LIMIT 500;
```

### C2. Dead-click ratio by page

```sql
WITH dead AS (
  SELECT coalesce(properties.$current_url, '(missing)') AS url, count() AS dead_clicks
  FROM events
  WHERE event = '$dead_click' AND timestamp >= now() - INTERVAL 8 HOUR
  GROUP BY url
),
pv AS (
  SELECT coalesce(properties.$current_url, '(missing)') AS url, count() AS pageviews
  FROM events
  WHERE event = '$pageview' AND timestamp >= now() - INTERVAL 8 HOUR
  GROUP BY url
)
SELECT
  pv.url,
  coalesce(dead.dead_clicks, 0) AS dead_clicks,
  pv.pageviews,
  round(coalesce(dead.dead_clicks, 0) / nullIf(toFloat64(pv.pageviews), 0), 3) AS dead_click_ratio
FROM pv
LEFT JOIN dead ON pv.url = dead.url
ORDER BY dead_click_ratio DESC, dead_clicks DESC
LIMIT 300;
```

## 2D) Web Vitals and Performance

### D1. Web vitals by metric and page

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$web_vital_name, '(missing)') AS metric,
  round(avg(toFloat64OrZero(coalesce(properties.$web_vital_value, 0))), 2) AS avg_value,
  quantile(0.95)(toFloat64OrZero(coalesce(properties.$web_vital_value, 0))) AS p95_value,
  count() AS samples,
  uniq(distinct_id) AS users
FROM events
WHERE event = '$web_vitals'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, metric
ORDER BY metric, p95_value DESC, users DESC
LIMIT 600;
```

### D2. Slow pages intersected with frustration signals

```sql
WITH slow AS (
  SELECT
    coalesce(properties.$current_url, '(missing)') AS url,
    maxIf(toFloat64OrZero(coalesce(properties.$web_vital_value, 0)), coalesce(properties.$web_vital_name, '') = 'LCP') AS max_lcp,
    maxIf(toFloat64OrZero(coalesce(properties.$web_vital_value, 0)), coalesce(properties.$web_vital_name, '') IN ('INP', 'FID')) AS max_inp,
    maxIf(toFloat64OrZero(coalesce(properties.$web_vital_value, 0)), coalesce(properties.$web_vital_name, '') = 'CLS') AS max_cls
  FROM events
  WHERE event = '$web_vitals'
    AND timestamp >= now() - INTERVAL 8 HOUR
  GROUP BY url
),
friction AS (
  SELECT
    coalesce(properties.$current_url, '(missing)') AS url,
    countIf(event = '$rageclick') AS rage_clicks,
    countIf(event = '$dead_click') AS dead_clicks
  FROM events
  WHERE timestamp >= now() - INTERVAL 8 HOUR
    AND event IN ('$rageclick', '$dead_click')
  GROUP BY url
)
SELECT
  s.url,
  s.max_lcp,
  s.max_inp,
  s.max_cls,
  coalesce(f.rage_clicks, 0) AS rage_clicks,
  coalesce(f.dead_clicks, 0) AS dead_clicks
FROM slow s
LEFT JOIN friction f ON s.url = f.url
ORDER BY (coalesce(f.rage_clicks, 0) + coalesce(f.dead_clicks, 0)) DESC, s.max_lcp DESC
LIMIT 300;
```

## 2E) Navigation and Broken Links

### E1. 404 / error landing pages

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$referrer, '(missing)') AS referrer,
  count() AS pageviews,
  uniq(distinct_id) AS users
FROM events
WHERE event = '$pageview'
  AND timestamp >= now() - INTERVAL 8 HOUR
  AND (
    lowerUTF8(coalesce(properties.$current_url, '')) LIKE '%404%'
    OR lowerUTF8(coalesce(properties.$current_url, '')) LIKE '%error%'
  )
GROUP BY url, referrer
ORDER BY pageviews DESC, users DESC
LIMIT 300;
```

### E2. Bounce risk pages (single pageview sessions)

```sql
WITH session_pageviews AS (
  SELECT
    coalesce(properties.$session_id, '') AS session_id,
    countIf(event = '$pageview') AS pageviews,
    anyLast(coalesce(properties.$current_url, '(missing)')) AS last_url
  FROM events
  WHERE timestamp >= now() - INTERVAL 8 HOUR
    AND coalesce(properties.$session_id, '') != ''
    AND event IN ('$pageview', '$pageleave')
  GROUP BY session_id
)
SELECT
  last_url AS url,
  countIf(pageviews = 1) AS single_page_sessions,
  count() AS total_sessions,
  round(single_page_sessions / nullIf(toFloat64(total_sessions), 0), 3) AS single_page_rate
FROM session_pageviews
GROUP BY url
ORDER BY single_page_rate DESC, total_sessions DESC
LIMIT 300;
```

## 2F) Flow and Conversion Failures

Use event names from your product for each core flow. First discover likely flow events:

```sql
SELECT event, count() AS events
FROM events
WHERE timestamp >= now() - INTERVAL 8 HOUR
  AND (
    lowerUTF8(event) LIKE '%signup%'
    OR lowerUTF8(event) LIKE '%login%'
    OR lowerUTF8(event) LIKE '%checkout%'
    OR lowerUTF8(event) LIKE '%payment%'
    OR lowerUTF8(event) LIKE '%post%'
    OR lowerUTF8(event) LIKE '%publish%'
  )
GROUP BY event
ORDER BY events DESC
LIMIT 200;
```

Then build step-dropoff query per flow:

```sql
WITH steps AS (
  SELECT
    distinct_id,
    minIf(timestamp, event = 'signup_started') AS step_1,
    minIf(timestamp, event = 'signup_submitted') AS step_2,
    minIf(timestamp, event = 'signup_success') AS step_3
  FROM events
  WHERE timestamp >= now() - INTERVAL 8 HOUR
    AND event IN ('signup_started', 'signup_submitted', 'signup_success')
  GROUP BY distinct_id
)
SELECT
  countIf(step_1 IS NOT NULL) AS started,
  countIf(step_2 IS NOT NULL) AS submitted,
  countIf(step_3 IS NOT NULL) AS success,
  (started - submitted) AS drop_before_submit,
  (submitted - success) AS drop_before_success
FROM steps;
```

## 3A) Frustration Score per Session

```sql
WITH session_signals AS (
  SELECT
    coalesce(properties.$session_id, '') AS session_id,
    anyLast(coalesce(properties.$current_url, '(missing)')) AS last_url,
    countIf(event = '$exception') AS exceptions,
    countIf(event = '$rageclick') AS rage_clicks,
    countIf(event = '$dead_click') AS dead_clicks,
    countIf(event = '$console_log' AND coalesce(properties.$console_log_level, '') = 'error') AS console_errors,
    min(timestamp) AS first_seen,
    max(timestamp) AS last_seen
  FROM events
  WHERE timestamp >= now() - INTERVAL 8 HOUR
    AND coalesce(properties.$session_id, '') != ''
    AND event IN ('$exception', '$rageclick', '$dead_click', '$console_log', '$pageview')
  GROUP BY session_id
)
SELECT
  session_id,
  last_url,
  exceptions,
  rage_clicks,
  dead_clicks,
  console_errors,
  round((exceptions * 3) + (rage_clicks * 2) + (dead_clicks * 1) + (console_errors * 1.5), 2) AS frustration_score,
  first_seen,
  last_seen
FROM session_signals
ORDER BY frustration_score DESC
LIMIT 200;
```

## 5) Trend and Recurrence Windows

### T1. Current 8h vs previous 8h totals

```sql
SELECT
  period,
  countIf(event = '$exception') AS exceptions,
  countIf(event = '$rageclick') AS rage_clicks,
  countIf(event = '$dead_click') AS dead_clicks,
  uniqIf(distinct_id, event IN ('$exception', '$rageclick', '$dead_click')) AS frustrated_users
FROM (
  SELECT
    event,
    distinct_id,
    if(timestamp >= now() - INTERVAL 8 HOUR, 'current_8h', 'previous_8h') AS period
  FROM events
  WHERE timestamp >= now() - INTERVAL 16 HOUR
    AND event IN ('$exception', '$rageclick', '$dead_click')
)
GROUP BY period
ORDER BY period;
```

### T2. Last 6h vs same 6h two days ago (fingerprints)

```sql
WITH source AS (
  SELECT
    if(timestamp >= now() - INTERVAL 6 HOUR, 'current_6h', 'baseline_6h') AS period,
    if(event = '$exception', 'exception', if(event = '$rageclick', 'rage_click', if(event = '$dead_click', 'dead_click', 'other'))) AS issue_type,
    lowerUTF8(coalesce(properties.$current_url, '(missing)')) AS url,
    lowerUTF8(coalesce(
      properties.$exception_message,
      properties.$el_selector,
      properties.$el_text,
      '(missing)'
    )) AS issue_detail
  FROM events
  WHERE (
      timestamp >= now() - INTERVAL 6 HOUR
      OR (timestamp >= now() - INTERVAL 54 HOUR AND timestamp < now() - INTERVAL 48 HOUR)
    )
    AND event IN ('$exception', '$rageclick', '$dead_click')
),
agg AS (
  SELECT
    period,
    issue_type,
    url,
    issue_detail,
    concat(issue_type, '|', url, '|', issue_detail) AS issue_fingerprint,
    count() AS issue_count
  FROM source
  GROUP BY period, issue_type, url, issue_detail, issue_fingerprint
)
SELECT
  coalesce(c.issue_fingerprint, b.issue_fingerprint) AS issue_fingerprint,
  coalesce(c.issue_type, b.issue_type) AS issue_type,
  coalesce(c.url, b.url) AS url,
  coalesce(c.issue_detail, b.issue_detail) AS issue_detail,
  coalesce(c.issue_count, 0) AS current_6h_count,
  coalesce(b.issue_count, 0) AS baseline_6h_count,
  if(coalesce(c.issue_count, 0) = 0 AND coalesce(b.issue_count, 0) > 0, 'Addressed',
    if(coalesce(c.issue_count, 0) > 0 AND coalesce(b.issue_count, 0) = 0, 'New',
      if(coalesce(c.issue_count, 0) > coalesce(b.issue_count, 0), 'Regressed', 'Recurring')
    )
  ) AS status
FROM (SELECT * FROM agg WHERE period = 'current_6h') c
FULL OUTER JOIN (SELECT * FROM agg WHERE period = 'baseline_6h') b
  ON c.issue_fingerprint = b.issue_fingerprint
ORDER BY status, current_6h_count DESC, baseline_6h_count DESC
LIMIT 2000;
```

## 24h Critical Inventory

```sql
SELECT
  event,
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$exception_message, coalesce(properties.$el_selector, '(missing)')) AS detail,
  count() AS events,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE timestamp >= now() - INTERVAL 24 HOUR
  AND event IN ('$exception', '$rageclick', '$dead_click')
GROUP BY event, url, detail
ORDER BY users DESC, events DESC
LIMIT 1000;
```
