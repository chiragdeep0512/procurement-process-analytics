USE procurement_analytics;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 9.6/Uploads/events_prepared.csv'
INTO TABLE stg_procurement_events
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    event_id,
    spend_area,
    company_id,
    document_type,
    sub_spend_area,
    purchase_document_id,
    purchase_document_category,
    vendor_id,
    item_type,
    item_category,
    spend_classification,
    source_system_id,
    vendor_name,
    gr_based_invoice_verification,
    item_id,
    case_id,
    goods_receipt_required,
    event_user,
    event_resource,
    activity,
    source_cumulative_net_worth_eur,
    event_timestamp_raw,
    @csv_event_timestamp,
    @csv_event_year,
    date_review_reason,
    date_review_required
)
SET
    event_timestamp = NULLIF(@csv_event_timestamp, ''),
    event_year = NULLIF(@csv_event_year, '');

SHOW COUNT(*) WARNINGS;
SHOW WARNINGS LIMIT 10;