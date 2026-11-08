USE procurement_analytics;

SELECT
    process_category,
    COUNT(*) AS total_cases,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS case_share_pct,

    SUM(last_observed_clear_at IS NOT NULL)
        AS cases_with_observed_clear,

    SUM(last_observed_clear_at IS NULL)
        AS cases_without_observed_clear,

    SUM(has_date_review = 1)
        AS date_review_cases

FROM case_summary
GROUP BY process_category
ORDER BY total_cases DESC;
