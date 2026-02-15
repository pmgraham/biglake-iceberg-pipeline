CREATE TABLE `__PROJECT_ID__.silver.distribution_centers`
(
    id INT64,
    name STRING,
    city STRING,
    state STRING,
    latitude FLOAT64,
    longitude FLOAT64,
    silver_loaded_at TIMESTAMP
)
WITH CONNECTION `__PROJECT_ID__.__REGION__.__BIGLAKE_CONNECTION__`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://__BUCKET_NAME__/iceberg/silver/distribution_centers'
);
