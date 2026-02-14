import os


class Config:
    GCP_PROJECT: str = os.environ["GCP_PROJECT"]
    GCP_LOCATION: str = os.environ.get("GCP_LOCATION", "us-central1")
    GCS_BUCKET: str = os.environ["GCS_BUCKET"]
    EVENT_TOPIC: str = os.environ["EVENT_TOPIC"]
    BIGLAKE_CONNECTION: str = os.environ["BIGLAKE_CONNECTION"]
    ICEBERG_BASE_PATH: str = os.environ["ICEBERG_BASE_PATH"]
