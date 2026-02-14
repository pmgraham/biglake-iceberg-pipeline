import logging
import uuid

from google.cloud import bigquery

from config import Config

logger = logging.getLogger(__name__)

_client = bigquery.Client(project=Config.GCP_PROJECT)

_CONNECTION_ID = (
    f"{Config.GCP_PROJECT}.{Config.GCP_LOCATION}.{Config.BIGLAKE_CONNECTION}"
)


def table_exists(namespace: str, table_name: str) -> bool:
    """Check if a BigQuery table already exists."""
    table_ref = f"{Config.GCP_PROJECT}.{namespace}.{table_name}"
    try:
        _client.get_table(table_ref)
        return True
    except Exception:
        return False


def create_iceberg_table(
    namespace: str,
    table_name: str,
    parquet_uri: str,
) -> str:
    """Create a new BigQuery Iceberg table and load initial data from parquet.

    Two-step approach:
    1. Create a temp external table to infer schema from the parquet file
    2. CREATE TABLE ... AS SELECT ... WITH CONNECTION ... OPTIONS(table_format='ICEBERG')

    BigQuery auto-registers the Iceberg table in the BigLake Metastore via
    the connection.

    Returns the BigQuery job ID as the load identifier.
    """
    storage_uri = f"{Config.ICEBERG_BASE_PATH}/{namespace}/{table_name}"
    table_ref = f"`{Config.GCP_PROJECT}.{namespace}.{table_name}`"
    connection_ref = f"`{_CONNECTION_ID}`"
    temp_suffix = uuid.uuid4().hex[:8]
    temp_table = f"`{Config.GCP_PROJECT}._pre_processing._temp_create_{temp_suffix}`"

    # Step 1: Create temp external table to infer schema from parquet
    create_temp_sql = f"""
    CREATE OR REPLACE EXTERNAL TABLE {temp_table}
    OPTIONS (
        format = 'PARQUET',
        uris = ['{parquet_uri}']
    )
    """
    _client.query(create_temp_sql).result()

    try:
        # Step 2: Create Iceberg table with data from temp table
        create_sql = f"""
        CREATE TABLE {table_ref}
        WITH CONNECTION {connection_ref}
        OPTIONS (
            file_format = 'PARQUET',
            table_format = 'ICEBERG',
            storage_uri = '{storage_uri}'
        )
        AS SELECT * FROM {temp_table}
        """
        job = _client.query(create_sql)
        job.result()
    finally:
        # Clean up temp table
        _client.query(f"DROP EXTERNAL TABLE IF EXISTS {temp_table}").result()

    load_id = job.job_id
    logger.info(
        "Created Iceberg table %s.%s — loaded from %s (job: %s)",
        namespace,
        table_name,
        parquet_uri,
        load_id,
    )
    return load_id


def load_data(
    namespace: str,
    table_name: str,
    parquet_uri: str,
    write_mode: str,
) -> str:
    """Load parquet data into an existing BigQuery Iceberg table.

    write_mode: APPEND or OVERWRITE.
    Returns the BigQuery job ID as the load identifier.
    """
    table_ref = f"`{Config.GCP_PROJECT}.{namespace}.{table_name}`"

    if write_mode == "OVERWRITE":
        load_statement = f"LOAD DATA OVERWRITE {table_ref}"
    else:
        load_statement = f"LOAD DATA INTO {table_ref}"

    sql = f"""
    {load_statement}
    FROM FILES (
        format = 'PARQUET',
        uris = ['{parquet_uri}']
    )
    """

    job = _client.query(sql)
    job.result()

    load_id = job.job_id
    logger.info(
        "%s %s.%s — loaded from %s (job: %s)",
        write_mode,
        namespace,
        table_name,
        parquet_uri,
        load_id,
    )
    return load_id


def upsert_data(
    namespace: str,
    table_name: str,
    parquet_uri: str,
    upsert_keys: list[str],
) -> str:
    """MERGE new parquet data into an existing Iceberg table using upsert keys.

    Creates a temp external table from the parquet, deletes matching rows
    by key from the target, then appends new data.

    Returns the BigQuery job ID as the load identifier.
    """
    table_ref = f"`{Config.GCP_PROJECT}.{namespace}.{table_name}`"
    temp_suffix = uuid.uuid4().hex[:8]
    temp_table = f"`{Config.GCP_PROJECT}._pre_processing._temp_upsert_{temp_suffix}`"

    # Create temporary external table pointing at the parquet file
    create_temp_sql = f"""
    CREATE OR REPLACE EXTERNAL TABLE {temp_table}
    OPTIONS (
        format = 'PARQUET',
        uris = ['{parquet_uri}']
    )
    """
    _client.query(create_temp_sql).result()

    try:
        # Delete rows in target that match incoming upsert keys
        join_condition = " AND ".join(
            f"target.{key} = source.{key}" for key in upsert_keys
        )

        delete_sql = f"""
        DELETE FROM {table_ref} AS target
        WHERE EXISTS (
            SELECT 1 FROM {temp_table} AS source
            WHERE {join_condition}
        )
        """
        _client.query(delete_sql).result()

        # Append new data
        load_sql = f"""
        LOAD DATA INTO {table_ref}
        FROM FILES (
            format = 'PARQUET',
            uris = ['{parquet_uri}']
        )
        """
        job = _client.query(load_sql)
        job.result()
    finally:
        # Clean up temp table
        _client.query(f"DROP EXTERNAL TABLE IF EXISTS {temp_table}").result()

    load_id = job.job_id
    logger.info(
        "UPSERT %s.%s — loaded from %s (job: %s)",
        namespace,
        table_name,
        parquet_uri,
        load_id,
    )
    return load_id
