-- Bronze → Silver transformation: distribution_centers
-- Deduplicates by id, casts types, standardizes strings

INSERT INTO `biglake-iceberg-datalake.silver.distribution_centers`
(id, name, latitude, longitude, silver_loaded_at)

WITH deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY SAFE_CAST(id AS INT64)
            ORDER BY processed_at DESC
        ) AS row_rank
    FROM `biglake-iceberg-datalake.bronze.distribution_centers`
    WHERE is_duplicate_in_file = FALSE
)
SELECT
    SAFE_CAST(id AS INT64) AS id,

    CASE
        WHEN TRIM(UPPER(name)) IN ('N/A','NA','NONE','NULL','-','--','MISSING','#N/A','')
        THEN NULL
        ELSE INITCAP(TRIM(name))
    END AS name,

    latitude,
    longitude,
    CURRENT_TIMESTAMP() AS silver_loaded_at

FROM deduplicated
WHERE row_rank = 1;
