# --- Datasets ---

resource "google_bigquery_dataset" "pre_processing" {
  dataset_id    = "_pre_processing"
  friendly_name = "Pre-Processing Metadata"
  description   = "Pipeline observability — file manifests, quality reports, cleaning reports"
  location      = var.region
  project       = google_project.pipeline.project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "bronze" {
  dataset_id    = "bronze"
  friendly_name = "Bronze"
  description   = "Iceberg tables via BigLake Metastore — agent-cleaned data"
  location      = var.region
  project       = google_project.pipeline.project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "silver" {
  dataset_id    = "silver"
  friendly_name = "Silver"
  description   = "Iceberg tables — conformed, typed, business logic applied"
  location      = var.region
  project       = google_project.pipeline.project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "gold" {
  dataset_id    = "gold"
  friendly_name = "Gold"
  description   = "Iceberg tables — aggregated, business-ready, modeled"
  location      = var.region
  project       = google_project.pipeline.project_id

  depends_on = [google_project_service.required_apis]
}

# --- File Manifest Table ---

resource "google_bigquery_table" "file_manifest" {
  dataset_id = google_bigquery_dataset.pre_processing.dataset_id
  table_id   = "file_manifest"
  project    = google_project.pipeline.project_id

  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }

  clustering = ["status", "target_table"]

  schema = jsonencode([
    { name = "file_hash", type = "STRING", mode = "REQUIRED", description = "SHA-256 hash of file contents" },
    { name = "file_name", type = "STRING", mode = "NULLABLE" },
    { name = "file_path", type = "STRING", mode = "NULLABLE" },
    { name = "file_type", type = "STRING", mode = "NULLABLE" },
    { name = "file_size_bytes", type = "INTEGER", mode = "NULLABLE" },
    { name = "target_namespace", type = "STRING", mode = "NULLABLE" },
    { name = "target_table", type = "STRING", mode = "NULLABLE" },
    { name = "status", type = "STRING", mode = "NULLABLE" },
    { name = "parquet_uri", type = "STRING", mode = "NULLABLE" },
    { name = "quality_report_uri", type = "STRING", mode = "NULLABLE" },
    { name = "cleaning_report_uri", type = "STRING", mode = "NULLABLE" },
    { name = "archive_uri", type = "STRING", mode = "NULLABLE" },
    { name = "row_count_raw", type = "INTEGER", mode = "NULLABLE" },
    { name = "row_count_cleaned", type = "INTEGER", mode = "NULLABLE" },
    { name = "row_count_loaded", type = "INTEGER", mode = "NULLABLE" },
    { name = "columns_detected", type = "STRING", mode = "REPEATED" },
    { name = "iceberg_snapshot_id", type = "STRING", mode = "NULLABLE" },
    { name = "write_mode", type = "STRING", mode = "NULLABLE" },
    { name = "error_message", type = "STRING", mode = "NULLABLE" },
    { name = "error_code", type = "STRING", mode = "NULLABLE" },
    { name = "error_stage", type = "STRING", mode = "NULLABLE" },
    { name = "retry_count", type = "INTEGER", mode = "NULLABLE" },
    { name = "processing_duration_seconds", type = "FLOAT", mode = "NULLABLE" },
    { name = "load_duration_seconds", type = "FLOAT", mode = "NULLABLE" },
    { name = "created_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "cleaned_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "last_loaded_at", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "updated_at", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}
