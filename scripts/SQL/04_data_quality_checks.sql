USE procurement_analytics;

SELECT
    -- Required fields mein NULL ya blank values
    SUM(
        COALESCE(TRIM(event_id), '') = ''
        OR COALESCE(TRIM(case_id), '') = ''
        OR COALESCE(TRIM(purchase_document_id), '') = ''
        OR COALESCE(TRIM(item_id), '') = ''
        OR COALESCE(TRIM(activity), '') = ''
        OR COALESCE(TRIM(event_timestamp_raw), '') = ''
    ) AS missing_required_rows,

    -- Case ID = purchase document + "_" + item
    SUM(
        NOT (
            case_id <=>
            CONCAT(purchase_document_id, '_', item_id)
        )
    ) AS case_key_mismatches,

    -- Parsed timestamp missing hai?
    SUM(
        event_timestamp IS NULL
    ) AS missing_parsed_timestamps,

    -- Raw timestamp aur parsed timestamp match karte hain?
    SUM(
        NOT (
            event_timestamp <=>
            STR_TO_DATE(
                event_timestamp_raw,
                '%d-%m-%Y %H:%i:%s.%f'
            )
        )
    ) AS timestamp_mismatches,

    -- Stored year timestamp ke year se match karta hai?
    SUM(
        NOT (
            event_year <=> YEAR(event_timestamp)
        )
    ) AS year_mismatches,

    -- Review flag hamare preparation rule se match karta hai?
    SUM(
        NOT (
            date_review_required <=>
            CASE
                WHEN event_timestamp IS NULL
                     OR YEAR(event_timestamp)
                        NOT BETWEEN 2018 AND 2019
                THEN 1
                ELSE 0
            END
        )
    ) AS review_flag_mismatches

FROM stg_procurement_events;