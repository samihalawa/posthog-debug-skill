# HogQL Query Pack

Run the query groups that match the chosen mode. For `full_audit`, run all of them.

Window defaults:

- `CURRENT_8H_START = now() - INTERVAL 8 HOUR`
- `PREV_8H_START = now() - INTERVAL 16 HOUR`
- `PREV_8H_END = now() - INTERVAL 8 HOUR`
- `CURRENT_48H_START = now() - INTERVAL 48 HOUR`
- `PREV_48H_START = now() - INTERVAL 96 HOUR`
- `PREV_48H_END = now() - INTERVAL 48 HOUR`
- `CURRENT_6H_START = now() - INTERVAL 6 HOUR`
- `BASELINE_6H_START = now() - INTERVAL 54 HOUR`
- `BASELINE_6H_END = now() - INTERVAL 48 HOUR`
- `CURRENT_24H_START = now() - INTERVAL 24 HOUR`
- `CURRENT_7D_START = now() - INTERVAL 7 DAY`

## 0) Property Discovery

```sql
SELECT key, count() AS events
FROM (
  SELECT arrayJoin(mapKeys(properties)) AS key
  FROM events
  WHERE timestamp >= now() - INTERVAL 48 HOUR
)
GROUP BY key
ORDER BY events DESC
LIMIT 300;
```

## 1A) Top Event Inventory (48h)

```sql
SELECT
  event,
  count() AS events,
  uniq(distinct_id) AS users
FROM events
WHERE timestamp >= now() - INTERVAL 48 HOUR
GROUP BY event
ORDER BY events DESC, users DESC
LIMIT 300;
```

## 1B) Top Page Inventory (48h)

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  count() AS pageviews,
  uniq(distinct_id) AS users
FROM events
WHERE event = '$pageview'
  AND timestamp >= now() - INTERVAL 48 HOUR
GROUP BY url
ORDER BY pageviews DESC, users DESC
LIMIT 300;
```

## 1C) Daily Trend (7d)

```sql
SELECT
  toDate(timestamp) AS day,
  countIf(event = '$pageview') AS pageviews,
  uniqIf(distinct_id, event = '$pageview') AS active_users,
  countIf(lowerUTF8(event) LIKE '%signup%' OR lowerUTF8(event) LIKE '%registration%') AS signup_events,
  countIf(lowerUTF8(event) LIKE '%listing%' OR lowerUTF8(event) LIKE '%post%') AS listing_events,
  countIf(lowerUTF8(event) LIKE '%payment%' OR lowerUTF8(event) LIKE '%checkout%' OR lowerUTF8(event) LIKE '%credit%') AS payment_events
FROM events
WHERE timestamp >= now() - INTERVAL 7 DAY
GROUP BY day
ORDER BY day ASC;
```

## 1D) Bucket Comparison (Current 48h vs Previous 48h)

```sql
WITH source AS (
  SELECT
    if(timestamp >= now() - INTERVAL 48 HOUR, 'current_48h', 'previous_48h') AS period,
    multiIf(
      lowerUTF8(event) LIKE '%payment%' OR lowerUTF8(event) LIKE '%checkout%' OR lowerUTF8(event) LIKE '%credit%' OR lowerUTF8(event) LIKE '%recharge%', 'payments',
      lowerUTF8(event) LIKE '%promote%' OR lowerUTF8(event) LIKE '%banner%', 'promotion',
      lowerUTF8(event) LIKE '%ai%' OR lowerUTF8(event) LIKE '%assistant%', 'ai',
      lowerUTF8(event) LIKE '%tv%' OR lowerUTF8(event) LIKE '%episode%' OR lowerUTF8(event) LIKE '%game%', 'media',
      lowerUTF8(event) LIKE '%support%' OR lowerUTF8(event) LIKE '%chat%', 'support',
      lowerUTF8(event) LIKE '%error%' OR lowerUTF8(event) LIKE '%timeout%' OR lowerUTF8(event) LIKE '%not_found%', 'custom_reliability',
      'other'
    ) AS bucket,
    distinct_id
  FROM events
  WHERE timestamp >= now() - INTERVAL 96 HOUR
)
SELECT
  bucket,
  period,
  count() AS events,
  uniq(distinct_id) AS users
FROM source
GROUP BY bucket, period
ORDER BY bucket, period;
```

## 1E) Payment and Promotion Event Ranking (48h)

```sql
SELECT
  event,
  count() AS events,
  uniq(distinct_id) AS users
FROM events
WHERE timestamp >= now() - INTERVAL 48 HOUR
  AND (
    lowerUTF8(event) LIKE '%payment%'
    OR lowerUTF8(event) LIKE '%checkout%'
    OR lowerUTF8(event) LIKE '%credit%'
    OR lowerUTF8(event) LIKE '%recharge%'
    OR lowerUTF8(event) LIKE '%promote%'
    OR lowerUTF8(event) LIKE '%banner%'
  )
GROUP BY event
ORDER BY events DESC, users DESC
LIMIT 300;
```

## 1F) Custom Reliability Signals (7d by day)

```sql
SELECT
  toDate(timestamp) AS day,
  event,
  count() AS events,
  uniq(distinct_id) AS users
FROM events
WHERE timestamp >= now() - INTERVAL 7 DAY
  AND (
    lowerUTF8(event) LIKE '%error%'
    OR lowerUTF8(event) LIKE '%timeout%'
    OR lowerUTF8(event) LIKE '%not_found%'
    OR lowerUTF8(event) LIKE '%failed%'
  )
GROUP BY day, event
ORDER BY day ASC, events DESC
LIMIT 500;
```

## 2A) Exceptions and Console Errors (8h)

```sql
SELECT
  coalesce(properties.$exception_message, '(missing)') AS exception_message,
  coalesce(properties.$exception_type, '(missing)') AS exception_type,
  toString(coalesce(properties.$exception_handled, 'unknown')) AS handled,
  coalesce(properties.$current_url, '(missing)') AS url,
  count() AS events,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$exception'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY exception_message, exception_type, handled, url
ORDER BY events DESC, users DESC
LIMIT 300;
```

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  count() AS console_error_events,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$console_log'
  AND coalesce(properties.$console_log_level, '') = 'error'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url
ORDER BY console_error_events DESC
LIMIT 300;
```

## 2B) Rage Clicks (8h)

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$el_text, '(no text)') AS element_text,
  coalesce(properties.$el_selector, '(no selector)') AS element_selector,
  count() AS rage_clicks,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$rageclick'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, element_text, element_selector
ORDER BY rage_clicks DESC, users DESC
LIMIT 300;
```

## 2C) Dead Clicks (8h)

```sql
SELECT
  coalesce(properties.$current_url, '(missing)') AS url,
  coalesce(properties.$el_text, '(no text)') AS element_text,
  coalesce(properties.$el_selector, '(no selector)') AS element_selector,
  count() AS dead_clicks,
  uniq(distinct_id) AS users,
  uniq(coalesce(properties.$session_id, '')) AS sessions
FROM events
WHERE event = '$dead_click'
  AND timestamp >= now() - INTERVAL 8 HOUR
GROUP BY url, element_text, element_selector
ORDER BY dead_clicks DESC, users DESC
LIMIT 300;
```

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

## 2D) Web Vitals and Performance (8h)

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

## 2E) Navigation and Broken Paths (8h)

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

## 2F) Flow and Conversion Failures

Discover relevant flow events first:

```sql
SELECT
  event,
  count() AS events,
  uniq(distinct_id) AS users
FROM events
WHERE timestamp >= now() - INTERVAL 48 HOUR
  AND (
    lowerUTF8(event) LIKE '%signup%'
    OR lowerUTF8(event) LIKE '%login%'
    OR lowerUTF8(event) LIKE '%listing%'
    OR lowerUTF8(event) LIKE '%post%'
    OR lowerUTF8(event) LIKE '%payment%'
    OR lowerUTF8(event) LIKE '%checkout%'
    OR lowerUTF8(event) LIKE '%credit%'
    OR lowerUTF8(event) LIKE '%recharge%'
    OR lowerUTF8(event) LIKE '%promote%'
    OR lowerUTF8(event) LIKE '%banner%'
  )
GROUP BY event
ORDER BY events DESC
LIMIT 300;
```

Monetization funnel snapshot for known Oulang-style events:

```sql
WITH steps AS (
  SELECT
    distinct_id,
    minIf(timestamp, event = 'recharge_page_viewed' OR event = 'credits_recharge_page_viewed') AS recharge_viewed_at,
    minIf(timestamp, event = 'payment_initiated' OR event = 'credits_purchase_initiated') AS payment_started_at,
    minIf(timestamp, event = 'payment_completed' OR event = 'credits_purchase_completed') AS payment_completed_at,
    minIf(timestamp, event = 'banner_checkout_started') AS banner_checkout_started_at,
    minIf(timestamp, event = 'banner_checkout_completed') AS banner_checkout_completed_at
  FROM events
  WHERE timestamp >= now() - INTERVAL 48 HOUR
    AND event IN (
      'recharge_page_viewed',
      'credits_recharge_page_viewed',
      'payment_initiated',
      'credits_purchase_initiated',
      'payment_completed',
      'credits_purchase_completed',
      'banner_checkout_started',
      'banner_checkout_completed'
    )
  GROUP BY distinct_id
)
SELECT
  countIf(recharge_viewed_at IS NOT NULL) AS recharge_viewers,
  countIf(payment_started_at IS NOT NULL) AS payment_starters,
  countIf(payment_completed_at IS NOT NULL) AS payment_completers,
  countIf(banner_checkout_started_at IS NOT NULL) AS banner_checkout_starters,
  countIf(banner_checkout_completed_at IS NOT NULL) AS banner_checkout_completers
FROM steps;
```

## 2G) Feature Adoption Comparison (Current 48h vs Previous 48h)

```sql
WITH source AS (
  SELECT
    if(timestamp >= now() - INTERVAL 48 HOUR, 'current_48h', 'previous_48h') AS period,
    multiIf(
      lowerUTF8(event) LIKE '%tv%' OR lowerUTF8(event) LIKE '%episode%', 'tv',
      lowerUTF8(event) LIKE '%game%', 'games',
      lowerUTF8(event) LIKE '%ai%', 'ai',
      lowerUTF8(event) LIKE '%support%' OR lowerUTF8(event) LIKE '%chat%', 'support',
      lowerUTF8(event) LIKE '%promote%' OR lowerUTF8(event) LIKE '%banner%', 'promotion',
      'other'
    ) AS feature,
    count() AS event_count,
    uniq(distinct_id) AS users
  FROM events
  WHERE timestamp >= now() - INTERVAL 96 HOUR
  GROUP BY period, feature
)
SELECT
  feature,
  period,
  event_count,
  users
FROM source
WHERE feature != 'other'
ORDER BY feature, period;
```

## 3A) Frustration Score per Session (8h)

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
  AND (
    event IN ('$exception', '$rageclick', '$dead_click')
    OR lowerUTF8(event) LIKE '%error%'
    OR lowerUTF8(event) LIKE '%timeout%'
    OR lowerUTF8(event) LIKE '%not_found%'
  )
GROUP BY event, url, detail
ORDER BY users DESC, events DESC
LIMIT 1000;
```
