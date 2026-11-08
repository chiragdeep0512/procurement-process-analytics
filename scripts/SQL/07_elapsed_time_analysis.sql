USE procurement_analytics;

WITH elapsed AS (
    SELECT
        case_id,
        process_category,
        has_date_review,

        CAST(
            TIMESTAMPDIFF(
                MICROSECOND,
                po_created_at,
                last_observed_clear_at
            ) AS DECIMAL(24, 6)
        ) / 86400000000 AS elapsed_days

    FROM case_summary
    WHERE case_attribute_issues = 0
      AND process_category <> 'Consignment'
      AND po_created_at IS NOT NULL
      AND last_observed_clear_at IS NOT NULL
      AND last_observed_clear_at >= po_created_at

      -- Temporary date-review policy for the two milestones
      AND YEAR(po_created_at) BETWEEN 2018 AND 2019
      AND YEAR(last_observed_clear_at) BETWEEN 2018 AND 2019
),

ranked AS (
    SELECT
        case_id,
        process_category,
        has_date_review,
        elapsed_days,

        ROW_NUMBER() OVER (
            PARTITION BY process_category
            ORDER BY elapsed_days, case_id
        ) AS rn,

        COUNT(*) OVER (
            PARTITION BY process_category
        ) AS n

    FROM elapsed
)

SELECT
    process_category,
    COUNT(*) AS measured_cases,

    ROUND(
        AVG(elapsed_days), 2
    ) AS mean_elapsed_days,

    ROUND(
        AVG(
            CASE
                WHEN rn IN (
                    FLOOR((n + 1) / 2),
                    FLOOR((n + 2) / 2)
                )
                THEN elapsed_days
            END
        ), 2
    ) AS median_elapsed_days,

    -- P90 using the nearest-rank method
    ROUND(
        MAX(
            CASE
                WHEN rn = CEIL(0.90 * n)
                THEN elapsed_days
            END
        ), 2
    ) AS p90_elapsed_days,

    SUM(has_date_review = 1)
        AS measured_cases_with_date_review

FROM ranked
GROUP BY process_category
ORDER BY measured_cases DESC;
