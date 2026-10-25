USE procurement_analytics;

CREATE TABLE IF NOT EXISTS case_summary (
    case_id VARCHAR(64) NOT NULL,
    PRIMARY KEY (case_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_bin
AS
SELECT
    case_id,
    MIN(purchase_document_id) AS purchase_document_id,
    MIN(item_id) AS item_id,
    MIN(vendor_id) AS vendor_id,
    MIN(company_id) AS company_id,
    MIN(item_category) AS process_category,

    COUNT(*) AS event_count,
    SUM(date_review_required = 1) AS date_review_event_count,
    MAX(date_review_required) AS has_date_review,

    -- First observed purchase-order creation
    MIN(CASE
        WHEN activity = 'Create Purchase Order Item'
        THEN event_timestamp
    END) AS po_created_at,

    -- First observed goods receipt
    MIN(CASE
        WHEN activity = 'Record Goods Receipt'
        THEN event_timestamp
    END) AS first_goods_receipt_at,

    -- First observed invoice receipt
    MIN(CASE
        WHEN activity = 'Record Invoice Receipt'
        THEN event_timestamp
    END) AS first_invoice_receipt_at,

    -- Latest clearing event available in the log
    MAX(CASE
        WHEN activity = 'Clear Invoice'
        THEN event_timestamp
    END) AS last_observed_clear_at,

    SUM(activity = 'Record Goods Receipt')
        AS goods_receipt_event_count,

    SUM(activity = 'Record Invoice Receipt')
        AS invoice_receipt_event_count,

    SUM(activity = 'Clear Invoice')
        AS clear_invoice_event_count,

    SUM(activity = 'Cancel Invoice Receipt')
        AS cancel_invoice_receipt_event_count,

    -- Check that case attributes stay consistent across events
    CASE
        WHEN MIN(purchase_document_id) = MAX(purchase_document_id)
         AND MIN(item_id) = MAX(item_id)
         AND MIN(vendor_id) = MAX(vendor_id)
         AND MIN(company_id) = MAX(company_id)
         AND MIN(item_category) = MAX(item_category)
        THEN 0
        ELSE 1
    END AS case_attribute_issues

FROM stg_procurement_events
GROUP BY case_id;




SELECT
    COUNT(*) AS total_cases,
    SUM(event_count) AS represented_events,
    SUM(date_review_event_count) AS date_review_events,
    SUM(has_date_review = 1) AS date_review_cases,
    SUM(case_attribute_issues) AS cases_with_attribute_issues
FROM procurement_analytics.case_summary;