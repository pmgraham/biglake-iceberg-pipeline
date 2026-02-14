import base64
import json
import logging
import time

import functions_framework
from cloudevents.http import CloudEvent

import cleanup
import iceberg_manager
import publisher
from message_parser import parse_load_request

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@functions_framework.cloud_event
def handle_pubsub(cloud_event: CloudEvent):
    raw = base64.b64decode(cloud_event.data["message"]["data"])
    message = json.loads(raw)

    start = time.time()
    request = None

    try:
        request = parse_load_request(message)

        logger.info(
            "Loading %s into %s.%s (mode: %s)",
            request["parquet_uri"],
            request["target_namespace"],
            request["target_table"],
            request["write_mode"],
        )

        data = iceberg_manager.read_parquet(request["parquet_uri"])

        catalog = iceberg_manager._get_catalog()
        namespace = request["target_namespace"]
        table_name = request["target_table"]

        if iceberg_manager.table_exists(catalog, namespace, table_name):
            snapshot_id = iceberg_manager.append_data(
                namespace=namespace,
                table_name=table_name,
                data=data,
                write_mode=request["write_mode"],
                upsert_keys=request.get("upsert_keys", []),
            )
        else:
            snapshot_id = iceberg_manager.create_and_load(
                namespace=namespace,
                table_name=table_name,
                data=data,
                partition_spec_config=request.get("partition_spec", []),
            )

        archive_uri = cleanup.archive_original(
            request["original_file_uri"],
            table_name,
        )
        cleanup.delete_staging_parquet(request["parquet_uri"])

        duration = time.time() - start

        publisher.publish_event({
            "type": "LOADER_BIGQUERY_COMPLETE",
            "file_hash": request["file_hash"],
            "target_namespace": namespace,
            "target_table": table_name,
            "iceberg_snapshot_id": snapshot_id,
            "write_mode": request["write_mode"],
            "row_count_loaded": len(data),
            "original_file_uri": request["original_file_uri"],
            "archive_uri": archive_uri,
            "load_duration_seconds": round(duration, 1),
        })

        logger.info(
            "Successfully loaded %d rows into %s.%s in %.1fs",
            len(data),
            namespace,
            table_name,
            duration,
        )

    except Exception as e:
        duration = time.time() - start

        error_payload = {
            "type": "LOADER_BIGQUERY_FAILED",
            "file_hash": request["file_hash"] if request else message.get("file_hash", "unknown"),
            "target_namespace": request["target_namespace"] if request else message.get("target_namespace", ""),
            "target_table": request["target_table"] if request else message.get("target_table", ""),
            "parquet_uri": request["parquet_uri"] if request else message.get("parquet_uri", ""),
            "error_message": str(e),
            "error_code": type(e).__name__,
            "retry_count": 0,
            "load_duration_seconds": round(duration, 1),
        }

        publisher.publish_event(error_payload)

        logger.exception("Load failed for %s", message.get("file_hash", "unknown"))

        # Raise to trigger Pub/Sub retry
        raise
