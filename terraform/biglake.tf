# BigLake Metastore catalog
resource "google_biglake_catalog" "pipeline" {
  provider = google-beta
  name     = var.iceberg_catalog_name
  location = var.region

  depends_on = [google_project_service.required_apis]
}

# BigQuery connection for BigLake Iceberg tables
resource "google_bigquery_connection" "biglake_iceberg" {
  provider      = google-beta
  connection_id = "biglake-iceberg"
  location      = var.region
  project       = google_project.pipeline.project_id

  cloud_resource {}

  depends_on = [google_project_service.required_apis]
}

# Grant the connection's service account access to GCS
resource "google_project_iam_member" "biglake_connection_storage" {
  project = google_project.pipeline.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_bigquery_connection.biglake_iceberg.cloud_resource[0].service_account_id}"
}

# BigQuery remote connection for Vertex AI model serving
resource "google_bigquery_connection" "vertex_ai" {
  provider      = google-beta
  connection_id = "vertex-ai-remote"
  location      = var.region
  project       = google_project.pipeline.project_id

  cloud_resource {}

  depends_on = [google_project_service.required_apis]
}

# Grant the Vertex AI connection's service account Vertex AI User role
resource "google_project_iam_member" "vertex_ai_connection_user" {
  project = google_project.pipeline.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_bigquery_connection.vertex_ai.cloud_resource[0].service_account_id}"
}
