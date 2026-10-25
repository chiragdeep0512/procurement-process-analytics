USE procurement_analytics;

CREATE TABLE IF NOT EXISTS stg_procurement_events (
    event_id VARCHAR(32) NOT NULL,
    spend_area VARCHAR(128),
    company_id VARCHAR(64),
    document_type VARCHAR(128),
    sub_spend_area VARCHAR(128),
    purchase_document_id VARCHAR(32) NOT NULL,
    purchase_document_category VARCHAR(128),
    vendor_id VARCHAR(64),
    item_type VARCHAR(128),
    item_category VARCHAR(128),
    spend_classification VARCHAR(64),
    source_system_id VARCHAR(64),
    vendor_name VARCHAR(255),
    gr_based_invoice_verification VARCHAR(16),
    item_id VARCHAR(16) NOT NULL,
    case_id VARCHAR(64) NOT NULL,
    goods_receipt_required VARCHAR(16),
    event_user VARCHAR(128),
    event_resource VARCHAR(128),
    activity VARCHAR(128) NOT NULL,
    source_cumulative_net_worth_eur VARCHAR(64),
    event_timestamp_raw VARCHAR(64) NOT NULL,
    event_timestamp DATETIME(6),
    event_year SMALLINT UNSIGNED,
    date_review_reason VARCHAR(64),
    date_review_required TINYINT UNSIGNED NOT NULL,

    PRIMARY KEY (event_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_bin;

-- Table ke columns check karo
SHOW COLUMNS FROM stg_procurement_events;

-- Abhi table empty honi chahiye
SELECT COUNT(*) AS total_events
FROM stg_procurement_events;

-- CSV import ke liye configuration dekho
SELECT
    VERSION() AS mysql_version,
    @@GLOBAL.local_infile AS local_infile,
    @@GLOBAL.secure_file_priv AS secure_file_priv;
    
    
    
    SELECT
    REPLACE(@@GLOBAL.secure_file_priv, CHAR(92), '/')
    AS import_folder;
    
