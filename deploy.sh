#!/usr/bin/env bash
set -euo pipefail

# Deploy Cloud Run services from source.
#
# Run this AFTER terraform apply to push actual service code.
# Terraform creates the service stubs (env vars, VPC, scaling, IAM);
# this script builds and deploys the container images.
#
# Usage:
#   ./deploy.sh                    # deploy all 3 services
#   ./deploy.sh data-agent         # deploy one service
#   ./deploy.sh file-loader pipeline-logger  # deploy specific services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Read project ID and region from Terraform outputs
# ---------------------------------------------------------------------------
TF_DIR="${SCRIPT_DIR}/terraform"

if [[ ! -f "${TF_DIR}/terraform.tfstate" ]] && [[ ! -d "${TF_DIR}/.terraform" ]]; then
    echo "ERROR: Terraform has not been initialized."
    echo "  cd terraform && terraform init && terraform apply"
    exit 1
fi

PROJECT=$(cd "${TF_DIR}" && terraform output -raw project_id 2>/dev/null) || true
if [[ -z "${PROJECT}" ]]; then
    echo "ERROR: Could not read project_id from Terraform outputs."
    echo "  Run 'terraform apply' first."
    exit 1
fi

# Read region from tfvars or default to us-central1
REGION=$(cd "${TF_DIR}" && terraform output -raw region 2>/dev/null 2>&1) || true
if [[ -z "${REGION}" ]]; then
    REGION="us-central1"
fi

echo "Project: ${PROJECT}"
echo "Region:  ${REGION}"
echo ""

# ---------------------------------------------------------------------------
# Service definitions
# ---------------------------------------------------------------------------
declare -A SERVICE_SOURCES=(
    ["data-agent"]="services/data-cleaning-agent"
    ["file-loader"]="services/loader"
    ["pipeline-logger"]="services/logger"
)

ALL_SERVICES=("data-agent" "file-loader" "pipeline-logger")

# ---------------------------------------------------------------------------
# Determine which services to deploy
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    SERVICES=("${ALL_SERVICES[@]}")
else
    SERVICES=("$@")
fi

# Validate service names
for svc in "${SERVICES[@]}"; do
    if [[ -z "${SERVICE_SOURCES[$svc]+x}" ]]; then
        echo "ERROR: Unknown service '${svc}'"
        echo "  Valid services: ${ALL_SERVICES[*]}"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
FAILED=()

for svc in "${SERVICES[@]}"; do
    source_dir="${SCRIPT_DIR}/${SERVICE_SOURCES[$svc]}"
    echo "--- Deploying ${svc} from ${SERVICE_SOURCES[$svc]}/ ---"

    if ! gcloud run deploy "${svc}" \
        --source "${source_dir}" \
        --region "${REGION}" \
        --project "${PROJECT}"; then
        echo "FAILED: ${svc}"
        FAILED+=("${svc}")
    else
        echo "OK: ${svc}"
    fi
    echo ""
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Deploy completed with errors:"
    for svc in "${FAILED[@]}"; do
        echo "  FAILED: ${svc}"
    done
    exit 1
else
    echo "All services deployed successfully."
fi
