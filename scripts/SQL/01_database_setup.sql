CREATE DATABASE IF NOT EXISTS procurement_analytics
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE procurement_analytics;

SELECT
    DATABASE() AS selected_database,
    VERSION() AS mysql_version,
    @@GLOBAL.local_infile AS local_infile,
    @@GLOBAL.secure_file_priv AS secure_file_priv;