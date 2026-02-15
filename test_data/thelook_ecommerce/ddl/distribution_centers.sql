CREATE TABLE `__PROJECT_ID__.bronze.distribution_centers`
WITH CONNECTION `__PROJECT_ID__.__REGION__.__BIGLAKE_CONNECTION__`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://__BUCKET_NAME__/iceberg/bronze/distribution_centers'
)
AS SELECT
    CAST(NULL AS INT64) AS id,
    CAST(NULL AS STRING) AS name,
    CAST(NULL AS FLOAT64) AS latitude,
    CAST(NULL AS FLOAT64) AS longitude
WHERE FALSE;
