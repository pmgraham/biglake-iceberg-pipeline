resource "google_cloud_run_v2_service" "pipeline_logger" {
  name     = "pipeline-logger"
  location = var.region
  project  = google_project.pipeline.project_id

  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.pipeline_logger.email

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    max_instance_request_concurrency = 1
    timeout                          = "60s"

    vpc_access {
      network_interfaces {
        network    = google_compute_network.pipeline.id
        subnetwork = google_compute_subnetwork.us_central1.id
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      # Placeholder — replaced by `gcloud run deploy --source`
      image = "us-docker.pkg.dev/cloudrun/container/placeholder"

      resources {
        limits = {
          memory = var.logger_memory
          cpu    = "1"
        }
      }

      env {
        name  = "GCP_PROJECT"
        value = google_project.pipeline.project_id
      }

      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.pipeline.name
      }
    }
  }

  depends_on = [google_project_service.required_apis]
}
