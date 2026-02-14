import logging

import pyarrow as pa
import pyarrow.parquet as pq
from gcsfs import GCSFileSystem
from pyiceberg.catalog import load_catalog
from pyiceberg.partitioning import PartitionField, PartitionSpec
from pyiceberg.schema import Schema
from pyiceberg.transforms import (
    DayTransform,
    IdentityTransform,
    MonthTransform,
    YearTransform,
)

from config import Config

logger = logging.getLogger(__name__)

_TRANSFORM_MAP = {
    "month": MonthTransform,
    "day": DayTransform,
    "year": YearTransform,
    "identity": IdentityTransform,
}


def _get_catalog():
    return load_catalog(
        "biglake",
        **{
            "type": "rest",
            "uri": "https://biglake.googleapis.com/iceberg/v1beta",
            "warehouse": (
                f"projects/{Config.GCP_PROJECT}"
                f"/locations/{Config.GCP_LOCATION}"
                f"/catalogs/{Config.ICEBERG_CATALOG}"
            ),
            "credential": "default",
        },
    )


def _get_gcs():
    return GCSFileSystem(project=Config.GCP_PROJECT)


def read_parquet(gcs_uri: str) -> pa.Table:
    gcs = _get_gcs()
    gcs_path = gcs_uri.replace("gs://", "")
    return pq.read_table(gcs_path, filesystem=gcs)


def table_exists(catalog, namespace: str, table_name: str) -> bool:
    try:
        catalog.load_table(f"{namespace}.{table_name}")
        return True
    except Exception:
        return False


def create_and_load(
    namespace: str,
    table_name: str,
    data: pa.Table,
    partition_spec_config: list[dict],
) -> str:
    catalog = _get_catalog()

    _ensure_namespace(catalog, namespace)

    table_identifier = f"{namespace}.{table_name}"
    location = f"{Config.ICEBERG_BASE_PATH}/{namespace}/{table_name}"

    iceberg_schema = Schema.from_arrow(data.schema)
    partition_spec = _build_partition_spec(partition_spec_config, iceberg_schema)

    table = catalog.create_table(
        identifier=table_identifier,
        schema=iceberg_schema,
        location=location,
        partition_spec=partition_spec,
    )

    table.append(data)
    snapshot_id = str(table.current_snapshot().snapshot_id)

    logger.info(
        "Created and loaded %s — %d rows, snapshot %s",
        table_identifier,
        len(data),
        snapshot_id,
    )
    return snapshot_id


def append_data(
    namespace: str,
    table_name: str,
    data: pa.Table,
    write_mode: str,
    upsert_keys: list[str],
) -> str:
    catalog = _get_catalog()
    table_identifier = f"{namespace}.{table_name}"
    table = catalog.load_table(table_identifier)

    with table.update_schema() as update:
        update.union_by_name(Schema.from_arrow(data.schema))

    if write_mode == "APPEND":
        table.append(data)
    elif write_mode == "OVERWRITE":
        table.overwrite(data)
    elif write_mode == "UPSERT":
        _upsert(table, data, upsert_keys)
    else:
        raise ValueError(f"Unsupported write_mode: {write_mode}")

    snapshot_id = str(table.current_snapshot().snapshot_id)

    logger.info(
        "%s %s — %d rows, snapshot %s",
        write_mode,
        table_identifier,
        len(data),
        snapshot_id,
    )
    return snapshot_id


def _upsert(table, new_data: pa.Table, keys: list[str]):
    existing = table.scan().to_arrow()

    key_set = set()
    for i in range(len(new_data)):
        key_vals = tuple(new_data.column(k)[i].as_py() for k in keys)
        key_set.add(key_vals)

    keep_mask = []
    for i in range(len(existing)):
        key_vals = tuple(existing.column(k)[i].as_py() for k in keys)
        keep_mask.append(key_vals not in key_set)

    filtered = existing.filter(keep_mask)
    merged = pa.concat_tables([filtered, new_data], promote_options="default")
    table.overwrite(merged)


def _ensure_namespace(catalog, namespace: str):
    try:
        catalog.create_namespace(namespace)
        logger.info("Created namespace: %s", namespace)
    except Exception:
        pass


def _build_partition_spec(
    spec_config: list[dict], schema: Schema
) -> PartitionSpec:
    if not spec_config:
        return PartitionSpec()

    fields = []
    for i, entry in enumerate(spec_config):
        field_name = entry["field"]
        transform_name = entry.get("transform", "identity")

        transform_cls = _TRANSFORM_MAP.get(transform_name)
        if not transform_cls:
            raise ValueError(f"Unknown partition transform: {transform_name}")

        source_field = schema.find_field(field_name)
        fields.append(
            PartitionField(
                source_id=source_field.field_id,
                field_id=1000 + i,
                transform=transform_cls(),
                name=f"{field_name}_{transform_name}",
            )
        )

    return PartitionSpec(*fields)
