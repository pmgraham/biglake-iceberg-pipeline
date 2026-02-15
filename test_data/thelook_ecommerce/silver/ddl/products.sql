CREATE TABLE `REDACTED_PROJECT.silver.products`
(
    id INT64,
    cost FLOAT64,
    category STRING,
    name STRING,
    brand STRING,
    retail_price FLOAT64,
    department STRING,
    sku STRING,
    distribution_center_id INT64,
    silver_loaded_at TIMESTAMP
)
WITH CONNECTION `REDACTED_PROJECT.us-central1.biglake-iceberg`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://REDACTED_BUCKET/iceberg/silver/products'
);
