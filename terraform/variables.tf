variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "biglake-iceberg-datalake"
}

variable "billing_account" {
  description = "GCP billing account ID"
  type        = string
}

variable "org_id" {
  description = "GCP organization ID (used if folder_id is not set)"
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "GCP folder ID to create the project under (takes precedence over org_id)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "GCS bucket name for the pipeline"
  type        = string
}

variable "iceberg_catalog_name" {
  description = "BigLake Metastore catalog name"
  type        = string
  default     = "data_pipeline_catalog"
}

variable "agent_image" {
  description = "Container image URI for the data agent Cloud Run service"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/placeholder"
}

variable "agent_memory" {
  description = "Memory allocation for the data agent"
  type        = string
  default     = "4Gi"
}

variable "agent_cpu" {
  description = "CPU allocation for the data agent"
  type        = string
  default     = "2"
}

variable "agent_timeout" {
  description = "Request timeout in seconds for the data agent"
  type        = number
  default     = 900
}

variable "agent_max_instances" {
  description = "Maximum number of data agent instances"
  type        = number
  default     = 10
}

variable "loader_memory" {
  description = "Memory allocation for the file loader"
  type        = string
  default     = "2Gi"
}

variable "logger_memory" {
  description = "Memory allocation for the pipeline logger"
  type        = string
  default     = "512Mi"
}
