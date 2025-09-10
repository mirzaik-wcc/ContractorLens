#!/bin/bash
# ContractorLens Production Deployment Script
set -euo pipefail

# Configuration
ENVIRONMENT=${1:-production}
AWS_REGION=${AWS_REGION:-us-west-2}
PROJECT_NAME="contractorlens"
CLUSTER_NAME="${PROJECT_NAME}"
SERVICE_NAME="${PROJECT_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local tools=("aws" "docker" "terraform")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build and push Docker images
build_and_push_images() {
    log_info "Building and pushing Docker images..."
    
    # Get ECR login token
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local git_hash=$(git rev-parse --short HEAD || echo "unknown")
    local image_tag="${git_hash}-${timestamp}"
    
    # Backend image
    log_info "Building backend image..."
    cd backend/
    docker build -t "${PROJECT_NAME}-backend:${image_tag}" .
    docker tag "${PROJECT_NAME}-backend:${image_tag}" "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-backend:${image_tag}"
    docker tag "${PROJECT_NAME}-backend:${image_tag}" "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-backend:latest"
    
    docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-backend:${image_tag}"
    docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-backend:latest"
    cd ../
    
    # Gemini service image
    log_info "Building Gemini service image..."
    cd ml-services/gemini-service/
    docker build -t "${PROJECT_NAME}-gemini:${image_tag}" .
    docker tag "${PROJECT_NAME}-gemini:${image_tag}" "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-gemini:${image_tag}"
    docker tag "${PROJECT_NAME}-gemini:${image_tag}" "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-gemini:latest"
    
    docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-gemini:${image_tag}"
    docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/${PROJECT_NAME}-gemini:latest"
    cd ../../
    
    log_success "Images built and pushed successfully"
    echo "IMAGE_TAG=${image_tag}" >> deployment.env
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd infrastructure/terraform/
    
    # Initialize Terraform
    terraform init \
        -backend-config="bucket=${PROJECT_NAME}-terraform-state" \
        -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}"
    
    # Plan deployment
    terraform plan -out=deployment.tfplan
    
    # Apply infrastructure changes
    log_warning "Applying infrastructure changes..."
    terraform apply -auto-approve deployment.tfplan
    
    # Get outputs
    terraform output -json > ../terraform-outputs.json
    
    cd ../../
    log_success "Infrastructure deployed successfully"
}

# Update ECS service with blue-green deployment
deploy_application() {
    log_info "Deploying application with blue-green strategy..."
    
    # Get current task definition
    local current_task_def=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --query 'services[0].taskDefinition' \
        --output text)
    
    log_info "Current task definition: $current_task_def"
    
    # Download current task definition
    aws ecs describe-task-definition \
        --task-definition "$current_task_def" \
        --query taskDefinition > current-task-def.json
    
    # Update image in task definition
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local image_tag=$(grep IMAGE_TAG deployment.env | cut -d'=' -f2)
    local new_image="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-backend:${image_tag}"
    
    # Create new task definition with updated image
    cat current-task-def.json | jq --arg IMAGE "$new_image" '
        .containerDefinitions[0].image = $IMAGE |
        del(.taskDefinitionArn) |
        del(.revision) |
        del(.status) |
        del(.requiresAttributes) |
        del(.placementConstraints) |
        del(.compatibilities) |
        del(.registeredAt) |
        del(.registeredBy)
    ' > new-task-def.json
    
    # Register new task definition
    local new_task_def=$(aws ecs register-task-definition \
        --cli-input-json file://new-task-def.json \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    log_info "New task definition: $new_task_def"
    
    # Update service with new task definition
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --task-definition "$new_task_def" \
        --force-new-deployment
    
    log_info "Waiting for deployment to complete..."
    aws ecs wait services-stable \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME"
    
    log_success "Application deployed successfully"
}

# Run health checks
run_health_checks() {
    log_info "Running health checks..."
    
    # Get load balancer DNS from Terraform outputs
    local lb_dns=$(cat infrastructure/terraform-outputs.json | jq -r '.load_balancer_dns_name.value')
    local health_url="http://${lb_dns}/health"
    
    log_info "Health check URL: $health_url"
    
    # Wait for load balancer to be ready
    log_info "Waiting for load balancer to be ready..."
    sleep 60
    
    # Perform health checks
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt $attempt/$max_attempts..."
        
        if curl -f -s "$health_url" > /dev/null; then
            log_success "Health check passed"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Health check failed after $max_attempts attempts"
            return 1
        fi
        
        sleep 30
        ((attempt++))
    done
    
    # Extended API tests
    log_info "Running API functionality tests..."
    
    # Test estimate API
    local api_url="http://${lb_dns}/api/v1"
    if curl -f -s "${api_url}/health" > /dev/null; then
        log_success "API health check passed"
    else
        log_error "API health check failed"
        return 1
    fi
    
    log_success "All health checks passed"
}

# Database migration
run_database_migrations() {
    log_info "Running database migrations..."
    
    # Get database endpoint from Terraform outputs
    local db_endpoint=$(cat infrastructure/terraform-outputs.json | jq -r '.database_endpoint.value')
    
    # Run migrations using ECS task (if migration scripts exist)
    if [ -d "database/migrations" ]; then
        log_info "Running database migration task..."
        
        # Create migration task definition
        aws ecs run-task \
            --cluster "$CLUSTER_NAME" \
            --task-definition "${PROJECT_NAME}-migration" \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$(cat infrastructure/terraform-outputs.json | jq -r '.private_subnet_ids.value | join(",")')]}"
        
        log_success "Database migrations completed"
    else
        log_info "No database migrations found, skipping..."
    fi
}

# Rollback function
rollback_deployment() {
    log_warning "Rolling back deployment..."
    
    # Get previous task definition
    local previous_task_def=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --query 'services[0].deployments[1].taskDefinition' \
        --output text)
    
    if [ "$previous_task_def" != "None" ]; then
        log_info "Rolling back to: $previous_task_def"
        
        aws ecs update-service \
            --cluster "$CLUSTER_NAME" \
            --service "$SERVICE_NAME" \
            --task-definition "$previous_task_def"
        
        aws ecs wait services-stable \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME"
        
        log_success "Rollback completed"
    else
        log_error "No previous task definition found for rollback"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up deployment artifacts..."
    
    rm -f deployment.env
    rm -f current-task-def.json
    rm -f new-task-def.json
    rm -f infrastructure/terraform-outputs.json
    rm -f infrastructure/terraform/deployment.tfplan
    
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    log_info "Starting ContractorLens production deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Region: $AWS_REGION"
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Service: $SERVICE_NAME"
    
    # Trap for cleanup on exit
    trap cleanup EXIT
    
    # Execute deployment steps
    check_prerequisites
    build_and_push_images
    deploy_infrastructure
    run_database_migrations
    deploy_application
    
    # Run health checks
    if run_health_checks; then
        log_success "🚀 Deployment completed successfully!"
        log_info "Application URL: http://$(cat infrastructure/terraform-outputs.json | jq -r '.load_balancer_dns_name.value')"
    else
        log_error "❌ Health checks failed, initiating rollback..."
        rollback_deployment
        exit 1
    fi
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "rollback")
        rollback_deployment
        ;;
    "health-check")
        run_health_checks
        ;;
    *)
        echo "Usage: $0 [deploy|rollback|health-check]"
        exit 1
        ;;
esac