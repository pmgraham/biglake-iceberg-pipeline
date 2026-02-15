# BigLake Iceberg Pipeline

Event-driven data pipeline using BigQuery Iceberg tables, Cloud Run, and an AI-powered data cleaning agent.

## Architecture

```
GCS (inbox/)
    │
    ▼ Eventarc trigger
Cloud Run: data-agent (ADK)
    │  ├─ quality assessment
    │  ├─ data cleaning
    │  └─ Parquet export → GCS (staging/)
    │
    ├─► Pub/Sub Topic A (LOAD_REQUEST)
    │       │
    │       ▼
    │   Cloud Run: file-loader
    │       └─ Creates/appends BigQuery Iceberg tables
    │
    └─► Pub/Sub Topic B (pipeline-events)
            │
            ▼
        Cloud Run: pipeline-logger
            └─ Writes to Firestore (file_registry)
```

## Medallion Architecture

| Layer | Format | Purpose |
|-------|--------|---------|
| **Bronze** | Iceberg | Raw landing zone — agent-cleaned, append-only |
| **Silver** | Iceberg | Deduplicated, typed, standardized |
| **Gold** | BigQuery Native | Business-ready — aggregations, vector search |

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated
- Terraform >= 1.5
- Python 3.12+
- Docker (for Cloud Run deploys)

## Quick Start

### 1. Configure

```bash
# Pipeline configuration (SQL templates, seed script)
cp pipeline.env.example pipeline.env
# Edit pipeline.env with your project ID, bucket name, etc.

# Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with billing account, project ID, bucket name
```

### 2. Set up SQL templates

```bash
chmod +x setup.sh
./setup.sh
```

### 3. Deploy infrastructure

```bash
cd terraform
terraform init -backend-config="bucket=YOUR_TF_STATE_BUCKET"
terraform plan -var-file=terraform.tfvars
terraform apply
```

### 4. Create Iceberg tables

Run the bronze DDL files in BigQuery to create empty Iceberg tables:

```bash
# Run each file in test_data/thelook_ecommerce/ddl/ via BigQuery Console or bq CLI
bq query --use_legacy_sql=false < test_data/thelook_ecommerce/ddl/distribution_centers.sql
bq query --use_legacy_sql=false < test_data/thelook_ecommerce/ddl/users.sql
# ... repeat for all 7 tables
```

### 5. Seed initial data

```bash
pip install google-cloud-bigquery
python test_data/thelook_ecommerce/seed.py
```

This loads data from `bigquery-public-data.thelook_ecommerce` into your bronze Iceberg tables.

### 6. Deploy Cloud Run services

```bash
gcloud run deploy data-agent --source services/data-cleaning-agent/ --region $REGION --project $PROJECT
gcloud run deploy file-loader --source services/loader/ --region $REGION --project $PROJECT
gcloud run deploy pipeline-logger --source services/logger/ --region $REGION --project $PROJECT
```

### 7. Test the pipeline

```bash
# Generate dirty incremental batch CSVs
pip install faker
python test_data/thelook_ecommerce/generate.py

# Upload a batch to trigger the pipeline
gsutil cp test_data/thelook_ecommerce/incremental/users/users_batch_001.csv \
  gs://YOUR_BUCKET/inbox/users/
```

## Project Structure

```
├── terraform/                          # GCP infrastructure (Terraform)
│   ├── main.tf                         # Project, providers, APIs
│   ├── variables.tf                    # All configurable variables
│   ├── terraform.tfvars.example        # Template for your values
│   ├── gcs.tf                          # GCS bucket and folders
│   ├── biglake.tf                      # BigLake, Vertex AI, Spark connections
│   ├── bigquery.tf                     # BigQuery datasets
│   ├── cloud_run_agent.tf              # Data agent service
│   ├── cloud_run_loader.tf             # File loader service
│   ├── cloud_run_logger.tf             # Pipeline logger service
│   ├── pubsub.tf                       # Pub/Sub topics and subscriptions
│   ├── eventarc.tf                     # GCS → data-agent trigger
│   ├── firestore.tf                    # Pipeline state database
│   ├── iam.tf                          # Service accounts and IAM
│   └── vpc.tf                          # VPC network
├── services/
│   ├── data-cleaning-agent/            # AI data cleaning agent (Google ADK)
│   ├── loader/                         # BigQuery Iceberg table loader
│   └── logger/                         # Pipeline event logger
├── test_data/
│   └── thelook_ecommerce/
│       ├── ddl/                        # Bronze Iceberg table DDL
│       ├── seed.py                     # Load from BigQuery public dataset
│       ├── generate.py                 # Generate dirty incremental CSVs
│       └── silver/                     # Silver layer DDL and transformations
├── pipeline.env.example                # Template for pipeline configuration
├── setup.sh                            # Configure SQL templates
├── DEMO.md                             # Demo scenarios and walkthrough
└── specs/                              # Integration specifications
```

## Services

### Data Cleaning Agent

AI-powered agent built on Google ADK (Agent Development Kit) that:
- Auto-detects file format (CSV, JSON, Parquet, Excel)
- Normalizes column names
- Coerces types (dates, numbers, booleans)
- Flags within-file duplicates
- Extracts currency symbols into companion columns
- Exports cleaned data as Parquet

### File Loader

Receives Pub/Sub messages from the agent and:
- Creates BigQuery Iceberg tables (if they don't exist)
- Appends Parquet data from GCS staging
- Publishes completion events

### Pipeline Logger

Records all pipeline events to Firestore for observability and duplicate detection.

## SQL Templating

SQL files under `test_data/` use placeholder tokens (`__PROJECT_ID__`, `__BUCKET_NAME__`, etc.) that are replaced by `setup.sh` using values from `pipeline.env`.

See `pipeline.env.example` for all available configuration options.
