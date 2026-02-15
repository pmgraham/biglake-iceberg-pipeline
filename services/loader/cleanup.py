import logging

from google.cloud import storage

from config import Config

logger = logging.getLogger(__name__)

_client = storage.Client(project=Config.GCP_PROJECT)
_pipeline_bucket = _client.bucket(Config.GCS_BUCKET)
_inbox_bucket = _client.bucket(Config.INBOX_BUCKET)


def archive_original(source_uri: str, target_table: str) -> str:
    """Move original file from inbox bucket to pipeline bucket's archive/."""
    source_path = source_uri.replace(f"gs://{Config.INBOX_BUCKET}/", "")
    filename = source_path.split("/")[-1]
    archive_path = f"archive/{target_table}/{filename}"

    source_blob = _inbox_bucket.blob(source_path)
    _inbox_bucket.copy_blob(source_blob, _pipeline_bucket, archive_path)
    source_blob.delete()

    archive_uri = f"gs://{Config.GCS_BUCKET}/{archive_path}"
    logger.info("Archived %s → %s", source_uri, archive_uri)
    return archive_uri


def delete_staging_parquet(parquet_uri: str):
    parquet_path = parquet_uri.replace(f"gs://{Config.GCS_BUCKET}/", "")
    blob = _pipeline_bucket.blob(parquet_path)
    blob.delete()
    logger.info("Deleted staging parquet: %s", parquet_uri)


def get_archive_uri(source_uri: str, target_table: str) -> str:
    source_path = source_uri.replace(f"gs://{Config.INBOX_BUCKET}/", "")
    filename = source_path.split("/")[-1]
    return f"gs://{Config.GCS_BUCKET}/archive/{target_table}/{filename}"
