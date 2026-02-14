# --- Dataplex Lake ---

resource "google_dataplex_lake" "pipeline" {
  provider = google-beta
  name     = "medallion-lakehouse"
  location = var.region
  project  = google_project.pipeline.project_id

  display_name = "Medallion Lakehouse"
  description  = "Data governance lake for the BigLake Iceberg medallion pipeline"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_project_service.required_apis]
}

# --- Zones (one per medallion tier + raw) ---

resource "google_dataplex_zone" "raw" {
  provider     = google-beta
  name         = "raw-zone"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  project      = google_project.pipeline.project_id
  type         = "RAW"
  display_name = "Raw Zone"
  description  = "Incoming raw files (inbox, staging, archive)"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled  = true
    schedule = "*/30 * * * *" # Every 30 minutes
  }
}

resource "google_dataplex_zone" "bronze" {
  provider     = google-beta
  name         = "bronze-zone"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  project      = google_project.pipeline.project_id
  type         = "CURATED"
  display_name = "Bronze Zone"
  description  = "Agent-cleaned data in Iceberg tables"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled  = true
    schedule = "*/30 * * * *"
  }
}

resource "google_dataplex_zone" "silver" {
  provider     = google-beta
  name         = "silver-zone"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  project      = google_project.pipeline.project_id
  type         = "CURATED"
  display_name = "Silver Zone"
  description  = "Conformed and typed Iceberg tables"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled  = true
    schedule = "0 * * * *" # Every hour
  }
}

resource "google_dataplex_zone" "gold" {
  provider     = google-beta
  name         = "gold-zone"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  project      = google_project.pipeline.project_id
  type         = "CURATED"
  display_name = "Gold Zone"
  description  = "Business-ready aggregated Iceberg tables"

  resource_spec {
    location_type = "SINGLE_REGION"
  }

  discovery_spec {
    enabled  = true
    schedule = "0 * * * *"
  }
}

# --- Assets (attach GCS + BigQuery to zones) ---

# Raw zone: GCS bucket (inbox, staging, archive)
resource "google_dataplex_asset" "raw_gcs" {
  provider     = google-beta
  name         = "pipeline-bucket"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  dataplex_zone = google_dataplex_zone.raw.name
  project      = google_project.pipeline.project_id
  display_name = "Pipeline GCS Bucket"
  description  = "Raw file storage — inbox, staging, archive"

  resource_spec {
    name = "projects/${google_project.pipeline.project_id}/buckets/${google_storage_bucket.pipeline.name}"
    type = "STORAGE_BUCKET"
  }

  discovery_spec {
    enabled  = true
    schedule = "*/30 * * * *"
  }
}

# Raw zone: _pre_processing dataset
resource "google_dataplex_asset" "raw_pre_processing" {
  provider     = google-beta
  name         = "pre-processing-dataset"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  dataplex_zone = google_dataplex_zone.raw.name
  project      = google_project.pipeline.project_id
  display_name = "Pre-Processing Dataset"
  description  = "Pipeline metadata — file manifests, reports"

  resource_spec {
    name = "projects/${google_project.pipeline.project_id}/datasets/${google_bigquery_dataset.pre_processing.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled  = true
    schedule = "*/30 * * * *"
  }
}

# Bronze zone: bronze dataset
resource "google_dataplex_asset" "bronze_dataset" {
  provider     = google-beta
  name         = "bronze-dataset"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  dataplex_zone = google_dataplex_zone.bronze.name
  project      = google_project.pipeline.project_id
  display_name = "Bronze Dataset"
  description  = "Iceberg tables — agent-cleaned data"

  resource_spec {
    name = "projects/${google_project.pipeline.project_id}/datasets/${google_bigquery_dataset.bronze.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled  = true
    schedule = "*/30 * * * *"
  }
}

# Silver zone: silver dataset
resource "google_dataplex_asset" "silver_dataset" {
  provider     = google-beta
  name         = "silver-dataset"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  dataplex_zone = google_dataplex_zone.silver.name
  project      = google_project.pipeline.project_id
  display_name = "Silver Dataset"
  description  = "Iceberg tables — conformed and typed"

  resource_spec {
    name = "projects/${google_project.pipeline.project_id}/datasets/${google_bigquery_dataset.silver.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled  = true
    schedule = "0 * * * *"
  }
}

# Gold zone: gold dataset
resource "google_dataplex_asset" "gold_dataset" {
  provider     = google-beta
  name         = "gold-dataset"
  location     = var.region
  lake         = google_dataplex_lake.pipeline.name
  dataplex_zone = google_dataplex_zone.gold.name
  project      = google_project.pipeline.project_id
  display_name = "Gold Dataset"
  description  = "Iceberg tables — business-ready aggregations"

  resource_spec {
    name = "projects/${google_project.pipeline.project_id}/datasets/${google_bigquery_dataset.gold.dataset_id}"
    type = "BIGQUERY_DATASET"
  }

  discovery_spec {
    enabled  = true
    schedule = "0 * * * *"
  }
}

# --- IAM: Grant Dataplex service account access to GCS and BigQuery ---

resource "google_project_iam_member" "dataplex_storage" {
  project = google_project.pipeline.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:service-${google_project.pipeline.number}@gcp-sa-dataplex.iam.gserviceaccount.com"

  depends_on = [google_dataplex_lake.pipeline]
}

resource "google_project_iam_member" "dataplex_bigquery" {
  project = google_project.pipeline.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:service-${google_project.pipeline.number}@gcp-sa-dataplex.iam.gserviceaccount.com"

  depends_on = [google_dataplex_lake.pipeline]
}
