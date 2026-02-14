# --- Service Accounts ---

resource "google_service_account" "data_agent" {
  account_id   = "data-agent"
  display_name = "Data Agent"
  description  = "Service account for the data agent Cloud Run service"
  project      = google_project.pipeline.project_id
}

resource "google_service_account" "file_loader" {
  account_id   = "file-loader"
  display_name = "File Loader"
  description  = "Service account for the file loader Cloud Run function"
  project      = google_project.pipeline.project_id
}

resource "google_service_account" "pipeline_logger" {
  account_id   = "pipeline-logger"
  display_name = "Pipeline Logger"
  description  = "Service account for the pipeline logger Cloud Run function"
  project      = google_project.pipeline.project_id
}

resource "google_service_account" "eventarc_trigger" {
  account_id   = "eventarc-trigger"
  display_name = "Eventarc Trigger"
  description  = "Service account for Eventarc triggers and Pub/Sub push auth"
  project      = google_project.pipeline.project_id
}

# --- Data Agent Roles ---

resource "google_project_iam_member" "agent_storage" {
  project = google_project.pipeline.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.data_agent.email}"
}

resource "google_project_iam_member" "agent_pubsub" {
  project = google_project.pipeline.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.data_agent.email}"
}

resource "google_project_iam_member" "agent_firestore" {
  project = google_project.pipeline.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.data_agent.email}"
}

# --- File Loader Roles ---

resource "google_project_iam_member" "loader_storage" {
  project = google_project.pipeline.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.file_loader.email}"
}

resource "google_project_iam_member" "loader_pubsub" {
  project = google_project.pipeline.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.file_loader.email}"
}

resource "google_project_iam_member" "loader_bigquery" {
  project = google_project.pipeline.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.file_loader.email}"
}

resource "google_project_iam_member" "loader_biglake" {
  project = google_project.pipeline.project_id
  role    = "roles/biglake.admin"
  member  = "serviceAccount:${google_service_account.file_loader.email}"
}

resource "google_project_iam_member" "loader_dataplex" {
  project = google_project.pipeline.project_id
  role    = "roles/dataplex.developer"
  member  = "serviceAccount:${google_service_account.file_loader.email}"
}

# --- Pipeline Logger Roles ---

resource "google_project_iam_member" "logger_firestore" {
  project = google_project.pipeline.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.pipeline_logger.email}"
}

# --- Eventarc Trigger Roles ---

resource "google_project_iam_member" "eventarc_run_invoker" {
  project = google_project.pipeline.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.eventarc_trigger.email}"
}

resource "google_project_iam_member" "eventarc_receiver" {
  project = google_project.pipeline.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc_trigger.email}"
}
