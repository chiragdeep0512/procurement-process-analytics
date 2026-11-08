USE procurement_analytics;

WITH cancellation_cases AS (
    SELECT DISTINCT case_id
    FROM stg_procurement_events
    WHERE activity LIKE 'Cancel %'
),

base AS (
    SELECT
        s.case_id,
        s.process_category,

        CASE
            WHEN c.case_id IS NULL THEN 0
            ELSE 1
        END AS has_cancellation,

        CASE
            WHEN s.goods_receipt_event_count > 1
              OR s.invoice_receipt_event_count > 1
                THEN 'Repeated GR/IR'

            WHEN s.goods_receipt_event_count = 1
             AND s.invoice_receipt_event_count = 1
                THEN 'One GR + one IR'

            ELSE 'Missing GR/IR, no repeats'
        END AS receipt_pattern,

        s.po_created_at,
        s.last_observed_clear_at,
        s.clear_invoice_event_count

    FROM case_summary AS s

    LEFT JOIN cancellation_cases AS c
        ON c.case_id = s.case_id

    WHERE s.case_attribute_issues = 0
      AND s.process_category IN (
          '3-way match, invoice before GR',
          '3-way match, invoice after GR'
      )
),

profile AS (
    SELECT
        process_category,
        has_cancellation,
        receipt_pattern,
        COUNT(*) AS total_cases,

        SUM(
            clear_invoice_event_count = 0
        ) AS no_clear_event_cases

    FROM base

    GROUP BY
        process_category,
        has_cancellation,
        receipt_pattern
),

elapsed AS (
    SELECT
        case_id,
        process_category,
        has_cancellation,
        receipt_pattern,

        TIMESTAMPDIFF(
            MICROSECOND,
            po_created_at,
            last_observed_clear_at
        ) AS elapsed_us

    FROM base

    WHERE po_created_at IS NOT NULL
      AND last_observed_clear_at IS NOT NULL
      AND last_observed_clear_at >= po_created_at
      AND YEAR(po_created_at) BETWEEN 2018 AND 2019
      AND YEAR(last_observed_clear_at) BETWEEN 2018 AND 2019
),

ranked AS (
    SELECT
        elapsed.*,

        ROW_NUMBER() OVER (
            PARTITION BY
                process_category,
                has_cancellation,
                receipt_pattern
            ORDER BY elapsed_us, case_id
        ) AS group_rank,

        COUNT(*) OVER (
            PARTITION BY
                process_category,
                has_cancellation,
                receipt_pattern
        ) AS group_n

    FROM elapsed
),

duration_stats AS (
    SELECT
        process_category,
        has_cancellation,
        receipt_pattern,
        COUNT(*) AS measured_cases,

        ROUND(
            CAST(
                AVG(
                    CASE
                        WHEN group_rank IN (
                            FLOOR((group_n + 1) / 2),
                            FLOOR((group_n + 2) / 2)
                        )
                        THEN elapsed_us
                    END
                ) AS DECIMAL(24,6)
            ) / 86400000000,
            2
        ) AS median_po_to_clear_days,

        ROUND(
            CAST(
                MAX(
                    CASE
                        WHEN group_rank = CEIL(0.90 * group_n)
                        THEN elapsed_us
                    END
                ) AS DECIMAL(24,6)
            ) / 86400000000,
            2
        ) AS p90_po_to_clear_days

    FROM ranked

    GROUP BY
        process_category,
        has_cancellation,
        receipt_pattern
)

SELECT
    p.process_category,
    p.has_cancellation,
    p.receipt_pattern,
    p.total_cases,

    COALESCE(
        d.measured_cases, 0
    ) AS measured_cases,

    p.no_clear_event_cases,
    d.median_po_to_clear_days,
    d.p90_po_to_clear_days

FROM profile AS p

LEFT JOIN duration_stats AS d
    ON d.process_category = p.process_category
   AND d.has_cancellation = p.has_cancellation
   AND d.receipt_pattern = p.receipt_pattern

ORDER BY
    CASE
        WHEN p.process_category =
             '3-way match, invoice before GR' THEN 1
        ELSE 2
    END,
    p.has_cancellation,
    p.receipt_pattern;
