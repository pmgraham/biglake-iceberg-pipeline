import os


class Config:
    GCP_PROJECT: str = os.environ["GCP_PROJECT"]
    GCP_LOCATION: str = os.environ.get("GCP_LOCATION", "us-central1")
    GCS_BUCKET: str = os.environ["GCS_BUCKET"]
    EVENT_TOPIC: str = os.environ["EVENT_TOPIC"]
    ICEBERG_CATALOG: str = os.environ["ICEBERG_CATALOG"]
    ICEBERG_BASE_PATH: str = os.environ["ICEBERG_BASE_PATH"]
