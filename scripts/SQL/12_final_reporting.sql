USE procurement_analytics;

-- VIEW 1: One row per case

CREATE OR REPLACE VIEW vw_case_report AS

WITH cancellation_cases AS (
    SELECT DISTINCT case_id
    FROM stg_procurement_events
    WHERE activity LIKE 'Cancel %'
),

enriched AS (
    SELECT
        s.case_id,
        s.purchase_document_id,
        s.item_id,
        s.vendor_id,
        s.company_id,
        s.process_category,

        s.event_count,
        s.date_review_event_count,
        s.has_date_review,
        s.case_attribute_issues,

        s.po_created_at,
        s.first_goods_receipt_at,
        s.first_invoice_receipt_at,
        s.last_observed_clear_at,

        s.goods_receipt_event_count,
        s.invoice_receipt_event_count,
        s.clear_invoice_event_count,
        s.cancel_invoice_receipt_event_count,

        CASE
            WHEN c.case_id IS NULL THEN 0
            ELSE 1
        END AS has_cancellation,

        CASE
            WHEN s.clear_invoice_event_count > 0 THEN 1
            ELSE 0
        END AS has_observed_clear,

        CASE
            WHEN s.process_category NOT IN (
                '3-way match, invoice before GR',
                '3-way match, invoice after GR'
            )
                THEN 'Not profiled'

            WHEN s.goods_receipt_event_count > 1
              OR s.invoice_receipt_event_count > 1
                THEN 'Repeated GR/IR'

            WHEN s.goods_receipt_event_count = 1
             AND s.invoice_receipt_event_count = 1
                THEN 'One GR + one IR'

            ELSE 'Missing GR/IR, no repeats'
        END AS receipt_pattern,

        CASE
            WHEN b.case_id IS NULL THEN 0
            ELSE 1
        END AS is_stage_baseline,

        b.first_receipt_at AS baseline_first_receipt_at,
        b.second_receipt_at AS baseline_second_receipt_at,

        DATE_FORMAT(
            b.second_receipt_at, '%Y-%m'
        ) AS baseline_receipt_month,

        b.observed_receipt_order AS baseline_receipt_order,

        CASE
            WHEN s.case_attribute_issues = 0
             AND s.process_category <> 'Consignment'
             AND s.po_created_at IS NOT NULL
             AND s.last_observed_clear_at IS NOT NULL
             AND s.last_observed_clear_at >= s.po_created_at
             AND YEAR(s.po_created_at) BETWEEN 2018 AND 2019
             AND YEAR(s.last_observed_clear_at)
                 BETWEEN 2018 AND 2019

            THEN TIMESTAMPDIFF(
                MICROSECOND,
                s.po_created_at,
                s.last_observed_clear_at
            )
        END AS po_to_last_clear_us

    FROM case_summary AS s

    LEFT JOIN cancellation_cases AS c
        ON c.case_id = s.case_id

    LEFT JOIN stage_baseline_cases AS b
        ON b.case_id = s.case_id
)

SELECT
    enriched.*,

    CAST(
        po_to_last_clear_us AS DECIMAL(24,6)
    ) / 86400000000 AS po_to_last_clear_days

FROM enriched;


-- VIEW 2: Three stage rows per baseline case
-- Raw microseconds retain precision for later calculations.

CREATE OR REPLACE VIEW vw_stage_report AS

SELECT
    case_id,
    1 AS stage_order,
    'PO -> first receipt' AS stage_name,

    po_to_first_receipt_us AS elapsed_us,

    CAST(
        po_to_first_receipt_us AS DECIMAL(24,6)
    ) / 86400000000 AS elapsed_days

FROM stage_baseline_cases

UNION ALL

SELECT
    case_id,
    2 AS stage_order,
    'First -> second receipt' AS stage_name,

    first_to_second_receipt_us AS elapsed_us,

    CAST(
        first_to_second_receipt_us AS DECIMAL(24,6)
    ) / 86400000000 AS elapsed_days

FROM stage_baseline_cases

UNION ALL

SELECT
    case_id,
    3 AS stage_order,
    'Both receipts -> clear' AS stage_name,

    second_receipt_to_clear_us AS elapsed_us,

    CAST(
        second_receipt_to_clear_us AS DECIMAL(24,6)
    ) / 86400000000 AS elapsed_days

FROM stage_baseline_cases;


-- CHECK 1: Case-level reconciliation

SELECT
    COUNT(*) AS total_cases,

    COUNT(DISTINCT case_id) AS unique_cases,

    SUM(event_count) AS represented_events,

    SUM(has_date_review) AS date_review_cases,

    SUM(has_cancellation) AS cancellation_cases,

    SUM(has_observed_clear) AS cases_with_observed_clear,

    SUM(
        po_to_last_clear_us IS NOT NULL
    ) AS measured_po_to_clear_cases,

    SUM(is_stage_baseline) AS stage_baseline_cases

FROM vw_case_report;


-- CHECK 2: Stage-level reconciliation

SELECT
    stage_order,
    stage_name,

    COUNT(*) AS stage_rows,

    COUNT(DISTINCT case_id) AS unique_cases,

    SUM(
        elapsed_us IS NULL OR elapsed_us < 0
    ) AS invalid_intervals

FROM vw_stage_report

GROUP BY
    stage_order,
    stage_name

ORDER BY stage_order;



SELECT *
FROM procurement_analytics.vw_case_report
ORDER BY case_id;

SELECT *
FROM procurement_analytics.vw_stage_report
ORDER BY case_id, stage_order;




SELECT *
FROM procurement_analytics.vw_case_report
ORDER BY case_id;
