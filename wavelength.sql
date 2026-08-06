-- date scaffold containing every month a subscription is active
WITH date_scaffold AS (
    SELECT generate_series(
        '2019-01-01'::date,
        '2025-12-31'::date,
        '1 month'::interval
    )::date AS date
)
SELECT
    ds.date,
    s.subscription_id
FROM date_scaffold ds
LEFT JOIN subscriptions s
    ON DATE_TRUNC('month', ds.date) >= DATE_TRUNC('month', s.start_date)
    AND (s.end_date IS NULL OR DATE_TRUNC('month', ds.date) <= DATE_TRUNC('month', s.end_date))
ORDER BY s.subscription_id;


-- subscriptions with end and start months
SELECT
    *,
    DATE_TRUNC('month', start_date)::date AS start_month,
    DATE_TRUNC('month', end_date)::date AS end_month
FROM subscriptions


-- users table with the indie tier each user is in and their lifetime revenue
WITH date_scaffold AS (
    SELECT generate_series(
        '2019-01-01'::date,
        '2025-12-31'::date,
        '1 month'::interval
    )::date AS date
),
date_subscription_scaffold AS (
    SELECT
        ds.date,
        s.subscription_id
    FROM date_scaffold ds
    LEFT JOIN subscriptions s
        ON DATE_TRUNC('month', ds.date) >= DATE_TRUNC('month', s.start_date)
        AND (s.end_date IS NULL OR DATE_TRUNC('month', ds.date) <= DATE_TRUNC('month', s.end_date))
),
user_revenue AS (
    SELECT
        u.user_id,
        SUM(sub.monthly_price) AS total_revenue
    FROM date_subscription_scaffold dss
    LEFT JOIN subscriptions sub
        ON dss.subscription_id = sub.subscription_id
    LEFT JOIN users u
        ON sub.user_id = u.user_id
    GROUP BY u.user_id
),
music_type_counts AS (
    SELECT
        u.user_id,
        COUNT(DISTINCT st.play_id) FILTER (WHERE c.is_indie = TRUE AND st.seconds_played > 10) AS indie_play_count,
        COUNT(DISTINCT st.play_id) FILTER (WHERE st.seconds_played > 10) AS total_play_count
    FROM users u
    LEFT JOIN sessions sess
        ON u.user_id = sess.user_id
    LEFT JOIN session_tracks st
        ON sess.session_id = st.session_id
    LEFT JOIN content c
        ON st.content_id = c.content_id
    GROUP BY u.user_id
),
indie_rates AS (
    SELECT
        user_id,
        indie_play_count::numeric / NULLIF(total_play_count, 0) AS indie_rate
    FROM music_type_counts
),
indie_categories AS (
    SELECT
        user_id,
        CASE
            WHEN indie_rate >= .75 THEN 'top 75'
            WHEN indie_rate >= .5 AND indie_rate < .75 THEN 'top 50'
            ELSE 'bottom 50'
        END AS indie_percentile
    FROM indie_rates
)
SELECT
    u.*,
    ic.indie_percentile,
    ROUND(ur.total_revenue::numeric, 2) AS total_revenue
FROM users u
LEFT JOIN indie_categories ic
    ON u.user_id = ic.user_id
LEFT JOIN user_revenue ur
    ON u.user_id = ur.user_id;


