CREATE TABLE `REDACTED_PROJECT.silver.distribution_centers`
(
    id INT64,
    name STRING,
    city STRING,
    state STRING,
    latitude FLOAT64,
    longitude FLOAT64,
    silver_loaded_at TIMESTAMP
)
WITH CONNECTION `REDACTED_PROJECT.us-central1.biglake-iceberg`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://REDACTED_BUCKET/iceberg/silver/distribution_centers'
);
