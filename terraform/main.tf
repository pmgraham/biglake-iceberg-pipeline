terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "" # Set via -backend-config or terraform init
    prefix = "terraform/state"
  }
}

provider "google" {
  project = google_project.pipeline.project_id
  region  = var.region
}

provider "google-beta" {
  project = google_project.pipeline.project_id
  region  = var.region
}

# --- Project ---

resource "google_project" "pipeline" {
  name                = "BigLake Iceberg Medallion Lakehouse"
  project_id          = var.project_id
  billing_account     = var.billing_account
  folder_id           = var.folder_id != "" ? var.folder_id : null
  org_id              = var.folder_id == "" ? var.org_id : null
  auto_create_network = false

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# --- API Enablement ---

resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "biglake.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "vpcaccess.googleapis.com",
  ])

  project            = google_project.pipeline.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.pipeline]
}
