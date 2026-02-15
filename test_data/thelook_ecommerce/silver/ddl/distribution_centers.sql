CREATE TABLE `biglake-iceberg-datalake.silver.distribution_centers`
(
    id INT64,
    name STRING,
    latitude FLOAT64,
    longitude FLOAT64,
    silver_loaded_at TIMESTAMP
)
WITH CONNECTION `biglake-iceberg-datalake.us-central1.biglake-iceberg`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://pmgraham-biglake-pipeline/iceberg/silver/distribution_centers'
);
