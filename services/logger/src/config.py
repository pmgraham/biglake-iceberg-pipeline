import os


class Config:
    GCP_PROJECT: str = os.environ["GCP_PROJECT"]
    FIRESTORE_DATABASE: str = "pipeline-state"
    FILE_REGISTRY_COLLECTION: str = "file_registry"
    TABLE_ROUTING_COLLECTION: str = "table_routing"
