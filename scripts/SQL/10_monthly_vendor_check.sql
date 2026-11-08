USE procurement_analytics;

WITH base AS (
    SELECT
        b.case_id,

        DATE_FORMAT(
            b.second_receipt_at, '%Y-%m'
        ) AS receipt_month,

        CASE
            WHEN s.vendor_id IN (
                'vendorID_0136',
                'vendorID_0120',
                'vendorID_0103'
            )
            THEN s.vendor_id
            ELSE 'Other vendors'
        END AS vendor_group,

        b.second_receipt_to_clear_us AS elapsed_us

    FROM stage_baseline_cases AS b

    JOIN case_summary AS s
        ON s.case_id = b.case_id

    WHERE b.process_category =
          '3-way match, invoice before GR'
),

ranked AS (
    SELECT
        base.*,

        ROW_NUMBER() OVER (
            ORDER BY elapsed_us, case_id
        ) AS overall_rank,

        COUNT(*) OVER () AS overall_n,

        ROW_NUMBER() OVER (
            PARTITION BY receipt_month, vendor_group
            ORDER BY elapsed_us, case_id
        ) AS group_rank,

        COUNT(*) OVER (
            PARTITION BY receipt_month, vendor_group
        ) AS group_n

    FROM base
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
    r.receipt_month,
    r.vendor_group,

    COUNT(*) AS baseline_cases,

    ROUND(
        AVG(
            CASE
                WHEN r.group_rank IN (
                    FLOOR((r.group_n + 1) / 2),
                    FLOOR((r.group_n + 2) / 2)
                )
                THEN r.elapsed_us
            END
        ) / 86400000000,
        2
    ) AS median_days,

    ROUND(
        CAST(
            MAX(
                CASE
                    WHEN r.group_rank = CEIL(0.90 * r.group_n)
                    THEN r.elapsed_us
                END
            ) AS DECIMAL(24,6)
        ) / 86400000000,
        2
    ) AS p90_days,

    SUM(
        r.elapsed_us > t.overall_p90_us
    ) AS above_p90_cases,

    ROUND(
        100.0 * SUM(r.elapsed_us > t.overall_p90_us)
        / COUNT(*),
        2
    ) AS above_p90_pct

FROM ranked AS r

CROSS JOIN benchmark AS t

GROUP BY
    r.receipt_month,
    r.vendor_group

ORDER BY
    r.receipt_month,
    CASE
        WHEN r.vendor_group = 'Other vendors' THEN 1
        ELSE 0
    END,
    r.vendor_group;
