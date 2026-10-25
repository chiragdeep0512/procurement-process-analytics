-- Purchase-to-Pay Process Analytics: observed stages for simple 3-way cases.
-- Run after 05_case_summary.sql and 07_elapsed_time_analysis.sql.
-- MySQL 8.0+; prepared for the project's MySQL 9.6 connection.
-- Keep the Workbench connection read timeout at 900 seconds.
--
-- Cohort: one recorded GR, one recorded invoice receipt, one clearing,
-- no activity starting with 'Cancel ', consistent case attributes,
-- ordered milestones, and all four milestone dates within 2018-2019.
-- This is a narrower baseline than the cohort in script 07.
-- First/second receipt follow the observed timestamp order, not the category name.
-- Equal receipt timestamps do not establish which event happened first.
--
-- These are calendar intervals between recorded milestones. 'Both receipts'
-- does not establish that quantities or amounts match or payment is due.
-- A clearing event does not establish full case completion.
-- Stage medians and P90 values are not additive.
--
-- Snapshot: IF NOT EXISTS keeps an existing stage_baseline_cases table.
-- It does not refresh that table when upstream data or this logic changes.
-- Source: BPI Challenge 2019, DOI 10.4121/uuid:d06aff4b-79f0-45e6-8ec8-e19730c248f1.

USE procurement_analytics;

CREATE TABLE IF NOT EXISTS stage_baseline_cases (
    case_id VARCHAR(64) NOT NULL,
    PRIMARY KEY (case_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_bin
AS
WITH cancellation_cases AS (
    -- Materialize the cancellation case list once, then join by case ID.
    SELECT DISTINCT case_id
    FROM stg_procurement_events
    WHERE activity LIKE 'Cancel %'
),
eligible AS (
    SELECT
        s.case_id,
        s.process_category,
        s.has_date_review,
        s.po_created_at,
        s.first_goods_receipt_at,
        s.first_invoice_receipt_at,
        s.last_observed_clear_at,
        LEAST(
            s.first_goods_receipt_at,
            s.first_invoice_receipt_at
        ) AS first_receipt_at,
        GREATEST(
            s.first_goods_receipt_at,
            s.first_invoice_receipt_at
        ) AS second_receipt_at
    FROM case_summary AS s
    LEFT JOIN cancellation_cases AS c ON c.case_id = s.case_id
    WHERE s.process_category IN (
              '3-way match, invoice before GR',
              '3-way match, invoice after GR'
          )
      AND s.case_attribute_issues = 0
      AND s.goods_receipt_event_count = 1
      AND s.invoice_receipt_event_count = 1
      AND s.clear_invoice_event_count = 1
      AND c.case_id IS NULL
      AND s.po_created_at IS NOT NULL
      AND s.first_goods_receipt_at IS NOT NULL
      AND s.first_invoice_receipt_at IS NOT NULL
      AND s.last_observed_clear_at IS NOT NULL
      AND s.po_created_at <= s.first_goods_receipt_at
      AND s.po_created_at <= s.first_invoice_receipt_at
      AND s.last_observed_clear_at >= GREATEST(
              s.first_goods_receipt_at,
              s.first_invoice_receipt_at
          )
      -- Temporary milestone-date review policy, consistent with script 07.
      AND YEAR(s.po_created_at) BETWEEN 2018 AND 2019
      AND YEAR(s.first_goods_receipt_at) BETWEEN 2018 AND 2019
      AND YEAR(s.first_invoice_receipt_at) BETWEEN 2018 AND 2019
      AND YEAR(s.last_observed_clear_at) BETWEEN 2018 AND 2019
)
SELECT
    case_id,
    process_category,
    has_date_review,
    po_created_at,
    first_goods_receipt_at,
    first_invoice_receipt_at,
    last_observed_clear_at,
    first_receipt_at,
    second_receipt_at,
    CASE
        WHEN first_invoice_receipt_at < first_goods_receipt_at
            THEN 'invoice_first'
        WHEN first_goods_receipt_at < first_invoice_receipt_at
            THEN 'goods_first'
        ELSE 'same_timestamp'
    END AS observed_receipt_order,
    TIMESTAMPDIFF(
        MICROSECOND, po_created_at, first_receipt_at
    ) AS po_to_first_receipt_us,
    TIMESTAMPDIFF(
        MICROSECOND, first_receipt_at, second_receipt_at
    ) AS first_to_second_receipt_us,
    TIMESTAMPDIFF(
        MICROSECOND, second_receipt_at, last_observed_clear_at
    ) AS second_receipt_to_clear_us
FROM eligible;

SHOW COUNT(*) WARNINGS;
SHOW WARNINGS LIMIT 10;

-- RESULT 1: baseline reconciliation.
-- Expected: 168051 cases; 181 cases with a date-review flag on some event;
-- zero cases with negative/missing intervals; zero stage-total mismatches.
-- Integer microseconds make the stage-total reconciliation exact.
SELECT
    COUNT(*) AS baseline_cases,
    SUM(has_date_review = 1) AS baseline_cases_with_date_review,
    SUM(
        po_to_first_receipt_us IS NULL
        OR first_to_second_receipt_us IS NULL
        OR second_receipt_to_clear_us IS NULL
        OR po_to_first_receipt_us < 0
        OR first_to_second_receipt_us < 0
        OR second_receipt_to_clear_us < 0
    ) AS cases_with_interval_issues,
    SUM(
        NOT (
            (po_to_first_receipt_us
             + first_to_second_receipt_us
             + second_receipt_to_clear_us)
            <=> TIMESTAMPDIFF(
                MICROSECOND, po_created_at, last_observed_clear_at
            )
        )
    ) AS stage_total_mismatches
FROM stage_baseline_cases;

-- RESULT 2: coverage relative to the observed-clearing cohort from script 07.
-- Expected before GR: 173698 -> 160825 cases (92.59%).
-- Expected after GR:    9676 ->   7226 cases (74.68%).
WITH observed_clear_cohort AS (
    SELECT case_id, process_category
    FROM case_summary
    WHERE case_attribute_issues = 0
      AND process_category IN (
              '3-way match, invoice before GR',
              '3-way match, invoice after GR'
          )
      AND po_created_at IS NOT NULL
      AND last_observed_clear_at IS NOT NULL
      AND last_observed_clear_at >= po_created_at
      AND YEAR(po_created_at) BETWEEN 2018 AND 2019
      AND YEAR(last_observed_clear_at) BETWEEN 2018 AND 2019
)
SELECT
    c.process_category,
    COUNT(*) AS observed_clear_cases,
    COUNT(b.case_id) AS baseline_cases,
    ROUND(
        100.0 * COUNT(b.case_id) / NULLIF(COUNT(*), 0), 2
    ) AS baseline_coverage_pct,
    SUM(CASE WHEN b.has_date_review = 1 THEN 1 ELSE 0 END)
        AS baseline_cases_with_date_review
FROM observed_clear_cohort AS c
LEFT JOIN stage_baseline_cases AS b ON b.case_id = c.case_id
GROUP BY c.process_category
ORDER BY baseline_cases DESC;

-- RESULT 3: six rows: three observed stages for each of the two categories.
-- All three stages within a category use the same cases.
-- First receipt = whichever of GR / invoice receipt was recorded earlier.
-- Second receipt = whichever of GR / invoice receipt was recorded later.
WITH intervals AS (
    SELECT
        case_id, process_category,
        1 AS stage_order,
        'PO -> first receipt' AS stage_name,
        CAST(po_to_first_receipt_us AS DECIMAL(24, 6))
            / 86400000000 AS elapsed_days
    FROM stage_baseline_cases

    UNION ALL

    SELECT
        case_id, process_category,
        2 AS stage_order,
        'First -> second receipt' AS stage_name,
        CAST(first_to_second_receipt_us AS DECIMAL(24, 6))
            / 86400000000 AS elapsed_days
    FROM stage_baseline_cases

    UNION ALL

    SELECT
        case_id, process_category,
        3 AS stage_order,
        'Both receipts -> clear' AS stage_name,
        CAST(second_receipt_to_clear_us AS DECIMAL(24, 6))
            / 86400000000 AS elapsed_days
    FROM stage_baseline_cases
),
ranked AS (
    SELECT
        case_id, process_category, stage_order, stage_name, elapsed_days,
        ROW_NUMBER() OVER (
            PARTITION BY process_category, stage_order
            ORDER BY elapsed_days, case_id
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY process_category, stage_order
        ) AS n
    FROM intervals
)
SELECT
    process_category,
    stage_name,
    COUNT(*) AS measured_cases,
    ROUND(AVG(elapsed_days), 2) AS mean_days,
    ROUND(
        AVG(CASE
            WHEN rn IN (FLOOR((n + 1) / 2), FLOOR((n + 2) / 2))
            THEN elapsed_days
        END), 2
    ) AS median_days,
    ROUND(
        MAX(CASE
            WHEN rn = CEIL(0.90 * n) THEN elapsed_days
        END), 2
    ) AS p90_days
FROM ranked
GROUP BY process_category, stage_order, stage_name
ORDER BY process_category DESC, stage_order;
