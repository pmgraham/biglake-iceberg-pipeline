import logging

from google.cloud import dataplex_v1

from config import Config

logger = logging.getLogger(__name__)

_client = dataplex_v1.DataScanServiceClient()
_content_client = dataplex_v1.ContentServiceClient()
_metadata_client = dataplex_v1.MetadataServiceClient()


def trigger_discovery(namespace: str, table_name: str):
    """Trigger immediate Dataplex discovery for the zone that owns this namespace."""
    zone_map = {
        "bronze": "bronze-zone",
        "silver": "silver-zone",
        "gold": "gold-zone",
    }

    zone_name = zone_map.get(namespace)
    if not zone_name:
        logger.warning("No Dataplex zone mapped for namespace: %s", namespace)
        return

    asset_map = {
        "bronze": "bronze-dataset",
        "silver": "silver-dataset",
        "gold": "gold-dataset",
    }

    asset_name = asset_map.get(namespace)
    lake_name = f"projects/{Config.GCP_PROJECT}/locations/{Config.GCP_LOCATION}/lakes/medallion-lakehouse"
    zone_path = f"{lake_name}/zones/{zone_name}"
    asset_path = f"{zone_path}/assets/{asset_name}"

    try:
        client = dataplex_v1.DataplexServiceClient()
        # Trigger discovery by running the asset's discovery job
        # The RunAssetDiscovery API kicks off an immediate scan
        operation = client.run_asset_discovery(name=asset_path)
        logger.info(
            "Triggered Dataplex discovery for %s.%s (asset: %s)",
            namespace,
            table_name,
            asset_path,
        )
        # Fire-and-forget — don't wait for the operation to complete
        return operation
    except Exception:
        # Discovery trigger is best-effort — don't fail the pipeline
        logger.warning(
            "Failed to trigger Dataplex discovery for %s.%s — will catch up on scheduled scan",
            namespace,
            table_name,
            exc_info=True,
        )
        return None
