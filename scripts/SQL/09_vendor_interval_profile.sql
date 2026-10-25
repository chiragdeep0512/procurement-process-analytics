USE procurement_analytics;

-- QUERY 1: Selected cases aur overall P90 benchmark

WITH ranked AS (
    SELECT
        b.case_id,
        s.vendor_id,
        b.has_date_review,
        b.second_receipt_to_clear_us AS elapsed_us,

        ROW_NUMBER() OVER (
            ORDER BY b.second_receipt_to_clear_us, b.case_id
        ) AS overall_rank,

        COUNT(*) OVER () AS overall_n

    FROM stage_baseline_cases AS b

    JOIN case_summary AS s
        ON s.case_id = b.case_id

    WHERE b.process_category =
          '3-way match, invoice before GR'
),

benchmark AS (
    SELECT
        MAX(
            CASE
                WHEN overall_rank = CEIL(0.90 * overall_n)
                THEN elapsed_us
            END
        ) AS overall_p90_us

    FROM ranked
)

SELECT
    COUNT(*) AS baseline_cases,

    COUNT(DISTINCT r.vendor_id) AS vendors,

    ROUND(
        CAST(MAX(t.overall_p90_us) AS DECIMAL(24,6))
        / 86400000000,
        2
    ) AS overall_p90_days,

    SUM(
        r.elapsed_us > t.overall_p90_us
    ) AS above_p90_cases,

    SUM(
        r.has_date_review = 1
    ) AS review_flagged_cases

FROM ranked AS r

CROSS JOIN benchmark AS t;


-- QUERY 2: Overall P90 se upar sabse zyada cases wale 10 vendors
-- Har vendor ko SAME overall threshold se compare karenge.

WITH ranked AS (
    SELECT
        b.case_id,
        s.vendor_id,
        b.second_receipt_to_clear_us AS elapsed_us,

        ROW_NUMBER() OVER (
            ORDER BY b.second_receipt_to_clear_us, b.case_id
        ) AS overall_rank,

        COUNT(*) OVER () AS overall_n,

        ROW_NUMBER() OVER (
            PARTITION BY s.vendor_id
            ORDER BY b.second_receipt_to_clear_us, b.case_id
        ) AS vendor_rank,

        COUNT(*) OVER (
            PARTITION BY s.vendor_id
        ) AS vendor_n

    FROM stage_baseline_cases AS b

    JOIN case_summary AS s
        ON s.case_id = b.case_id

    WHERE b.process_category =
          '3-way match, invoice before GR'
),

benchmark AS (
    SELECT
        MAX(
            CASE
                WHEN overall_rank = CEIL(0.90 * overall_n)
                THEN elapsed_us
            END
        ) AS overall_p90_us

    FROM ranked
),

vendor_summary AS (
    SELECT
        r.vendor_id,

        COUNT(*) AS baseline_cases,

        AVG(r.elapsed_us) AS mean_us,

        AVG(
            CASE
                WHEN r.vendor_rank IN (
                    FLOOR((r.vendor_n + 1) / 2),
                    FLOOR((r.vendor_n + 2) / 2)
                )
                THEN r.elapsed_us
            END
        ) AS median_us,

        MAX(
            CASE
                WHEN r.vendor_rank = CEIL(0.90 * r.vendor_n)
                THEN r.elapsed_us
            END
        ) AS p90_us,

        SUM(
            r.elapsed_us > t.overall_p90_us
        ) AS above_p90_cases

    FROM ranked AS r

    CROSS JOIN benchmark AS t

    GROUP BY r.vendor_id
)

SELECT
    vendor_id,

    baseline_cases,

    ROUND(
        mean_us / 86400000000, 2
    ) AS mean_days,

    ROUND(
        median_us / 86400000000, 2
    ) AS median_days,

    ROUND(
        CAST(p90_us AS DECIMAL(24,6)) / 86400000000,
        2
    ) AS p90_days,

    above_p90_cases,

    ROUND(
        100.0 * above_p90_cases / baseline_cases,
        2
    ) AS above_p90_pct,

    ROUND(
        100.0 * above_p90_cases
        / NULLIF(SUM(above_p90_cases) OVER (), 0),
        2
    ) AS share_of_above_p90_pct

FROM vendor_summary

ORDER BY
    above_p90_cases DESC,
    baseline_cases DESC,
    vendor_id

LIMIT 10;