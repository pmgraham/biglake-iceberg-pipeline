CREATE TABLE `REDACTED_PROJECT.bronze.distribution_centers`
WITH CONNECTION `REDACTED_PROJECT.us-central1.biglake-iceberg`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://REDACTED_BUCKET/iceberg/bronze/distribution_centers'
)
AS SELECT
    CAST(NULL AS INT64) AS id,
    CAST(NULL AS STRING) AS name,
    CAST(NULL AS FLOAT64) AS latitude,
    CAST(NULL AS FLOAT64) AS longitude
WHERE FALSE;
