CREATE TABLE `REDACTED_PROJECT.silver.inventory_items`
(
    id INT64,
    product_id INT64,
    created_at TIMESTAMP,
    sold_at TIMESTAMP,
    cost FLOAT64,
    product_category STRING,
    product_name STRING,
    product_brand STRING,
    product_retail_price FLOAT64,
    product_department STRING,
    product_sku STRING,
    product_distribution_center_id INT64,
    silver_loaded_at TIMESTAMP
)
WITH CONNECTION `REDACTED_PROJECT.us-central1.biglake-iceberg`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://REDACTED_BUCKET/iceberg/silver/inventory_items'
);
