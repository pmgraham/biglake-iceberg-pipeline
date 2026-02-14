resource "google_storage_bucket" "pipeline" {
  name     = var.bucket_name
  location = var.region
  project  = google_project.pipeline.project_id

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

  # Safety net: auto-delete staging files after 1 day
  lifecycle_rule {
    condition {
      age                = 1
      matches_prefix     = ["staging/"]
    }
    action {
      type = "Delete"
    }
  }

  # Transition archive files to Nearline after 90 days
  lifecycle_rule {
    condition {
      age                = 90
      matches_prefix     = ["archive/"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Placeholder objects for folder structure
resource "google_storage_bucket_object" "folders" {
  for_each = toset([
    "inbox/",
    "staging/",
    "archive/",
    "reports/quality/",
    "reports/cleaning/",
    "iceberg/",
  ])

  bucket  = google_storage_bucket.pipeline.name
  name    = each.value
  content = ""
}
