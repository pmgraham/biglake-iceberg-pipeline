# BigLake Iceberg Pipeline

Event-driven data pipeline using BigQuery Iceberg tables, Cloud Run, and an AI-powered data cleaning agent.

---

## Getting Started

### Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated (`gcloud auth login && gcloud auth application-default login`)
- Terraform >= 1.5
- Python 3.12+
- Docker (for Cloud Run deploys)

### Step 1 — Clone and configure

```bash
git clone https://github.com/pmgraham/biglake-iceberg-pipeline.git
cd biglake-iceberg-pipeline

# Pipeline configuration (SQL templates, seed script)
cp pipeline.env.example pipeline.env
# Edit pipeline.env with your project ID, bucket names, etc.

# Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with billing account, project ID, bucket names
```

### Step 2 — Apply SQL templates

```bash
./setup.sh
```

Replaces placeholder tokens (`__PROJECT_ID__`, `__ICEBERG_BUCKET_NAME__`, etc.) in all SQL files with your values from `pipeline.env`.

### Step 3 — Deploy infrastructure

```bash
cd terraform
terraform init -backend-config="bucket=YOUR_TF_STATE_BUCKET"
terraform plan -var-file=terraform.tfvars
terraform apply
cd ..
```

Creates all GCP infrastructure: project, APIs, buckets, BigQuery datasets, bronze Iceberg tables, Cloud Run service stubs, Pub/Sub topics/subscriptions, Eventarc trigger, Firestore, VPC, IAM, and connections.

### Step 4 — Deploy Cloud Run services

```bash
./deploy.sh
```

Builds and deploys all 3 Cloud Run services from source. You can also deploy individually:

```bash
./deploy.sh data-agent          # deploy one service
./deploy.sh file-loader pipeline-logger  # deploy specific services
```

### Step 5 — Seed initial data

```bash
pip install google-cloud-bigquery
python test_data/thelook_ecommerce/seed.py
```

Loads data from `bigquery-public-data.thelook_ecommerce` into your bronze Iceberg tables (7 tables, ~3.3M rows).

### Step 6 — Test the pipeline

```bash
# Generate dirty incremental batch CSVs
pip install faker
python test_data/thelook_ecommerce/generate.py

# Upload a batch to trigger the pipeline
gsutil cp test_data/thelook_ecommerce/incremental/users/users_batch_001.csv \
  gs://YOUR_INBOX_BUCKET/users/
```

---

## Architecture

```
GCS Inbox Bucket (raw uploads)
    |
    v Eventarc trigger
Cloud Run: data-agent (ADK)
    |  |- quality assessment
    |  |- data cleaning
    |  '- Parquet export -> GCS Staging Bucket
    |
    |--> Pub/Sub Topic A (LOAD_REQUEST)
    |       |
    |       v
    |   Cloud Run: file-loader
    |       |- Creates/appends BigQuery Iceberg tables (GCS Iceberg Bucket)
    |       '- Archives originals (GCS Archive Bucket)
    |
    '--> Pub/Sub Topic B (pipeline-events)
            |
            v
        Cloud Run: pipeline-logger
            '- Writes to Firestore (file_registry)
```

## Medallion Architecture

| Layer | Format | Purpose |
|-------|--------|---------|
| **Bronze** | Iceberg | Raw landing zone — agent-cleaned, append-only |
| **Silver** | Iceberg | Deduplicated, typed, standardized |
| **Gold** | BigQuery Native | Business-ready — aggregations, vector search |

Bronze tables are created by Terraform. Silver and gold tables are created via SQL transformations (see `test_data/thelook_ecommerce/silver/` and `DEMO.md`).

## What Terraform Creates

| Resource | Details |
|----------|---------|
| GCP Project | With all required APIs enabled |
| GCS Buckets | inbox, staging (auto-delete 1d), iceberg (versioned), archive (Nearline 90d) |
| BigQuery | 3 datasets (bronze, silver, gold) + 7 bronze Iceberg tables with schemas |
| Cloud Run | 3 service stubs with env vars, VPC, scaling, IAM (code deployed via `deploy.sh`) |
| Pub/Sub | 2 topics + subscriptions + dead letter topic |
| Eventarc | GCS finalize trigger on inbox bucket |
| Firestore | pipeline-state database with composite indices |
| VPC | Custom network, subnets, Cloud NAT, Private Service Connect |
| IAM | 4 service accounts with least-privilege roles |
| Connections | BigLake, Vertex AI, Spark |

## Project Structure

```
├── terraform/                          # GCP infrastructure (Terraform)
│   ├── main.tf                         # Project, providers, APIs
│   ├── variables.tf                    # All configurable variables
│   ├── terraform.tfvars.example        # Template for your values
│   ├── gcs.tf                          # GCS buckets (inbox, staging, iceberg, archive)
│   ├── biglake.tf                      # BigLake, Vertex AI, Spark connections
│   ├── bigquery.tf                     # BigQuery datasets
│   ├── bigquery_tables.tf              # Bronze Iceberg table definitions
│   ├── cloud_run_agent.tf              # Data agent service
│   ├── cloud_run_loader.tf             # File loader service
│   ├── cloud_run_logger.tf             # Pipeline logger service
│   ├── pubsub.tf                       # Pub/Sub topics and subscriptions
│   ├── eventarc.tf                     # GCS -> data-agent trigger
│   ├── firestore.tf                    # Pipeline state database
│   ├── iam.tf                          # Service accounts and IAM
│   └── vpc.tf                          # VPC network
├── services/
│   ├── data-cleaning-agent/            # AI data cleaning agent (Google ADK)
│   ├── loader/                         # BigQuery Iceberg table loader
│   └── logger/                         # Pipeline event logger
├── test_data/
│   └── thelook_ecommerce/
│       ├── ddl/                        # Bronze Iceberg table DDL (reference)
│       ├── seed.py                     # Load from BigQuery public dataset
│       ├── generate.py                 # Generate dirty incremental CSVs
│       └── silver/                     # Silver layer DDL and transformations
├── pipeline.env.example                # Template for pipeline configuration
├── setup.sh                            # Configure SQL templates
├── deploy.sh                           # Deploy Cloud Run services from source
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

SQL files under `test_data/` use placeholder tokens (`__PROJECT_ID__`, `__ICEBERG_BUCKET_NAME__`, etc.) that are replaced by `setup.sh` using values from `pipeline.env`.

See `pipeline.env.example` for all available configuration options.
