#!/bin/bash
# ContractorLens Production Environment Setup Script
set -euo pipefail

# Configuration
AWS_REGION=${AWS_REGION:-us-west-2}
PROJECT_NAME="contractorlens"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create S3 bucket for Terraform state
create_terraform_backend() {
    log_info "Setting up Terraform backend..."
    
    local bucket_name="${PROJECT_NAME}-terraform-state"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    # Check if bucket exists
    if aws s3 ls "s3://${bucket_name}" 2>/dev/null; then
        log_info "Terraform state bucket already exists"
    else
        log_info "Creating Terraform state bucket..."
        aws s3 mb "s3://${bucket_name}" --region "$AWS_REGION"
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable server-side encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
        
        # Block public access
        aws s3api put-public-access-block \
            --bucket "$bucket_name" \
            --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    fi
    
    # Create DynamoDB table for state locking
    local table_name="${PROJECT_NAME}-terraform-locks"
    
    if aws dynamodb describe-table --table-name "$table_name" --region "$AWS_REGION" 2>/dev/null; then
        log_info "Terraform lock table already exists"
    else
        log_info "Creating Terraform lock table..."
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --region "$AWS_REGION"
        
        log_info "Waiting for table to be created..."
        aws dynamodb wait table-exists --table-name "$table_name" --region "$AWS_REGION"
    fi
    
    log_success "Terraform backend configured"
}

# Create ECR repositories
create_ecr_repositories() {
    log_info "Setting up ECR repositories..."
    
    local repositories=("${PROJECT_NAME}-backend" "${PROJECT_NAME}-gemini")
    
    for repo in "${repositories[@]}"; do
        if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" 2>/dev/null; then
            log_info "ECR repository '$repo' already exists"
        else
            log_info "Creating ECR repository '$repo'..."
            aws ecr create-repository \
                --repository-name "$repo" \
                --region "$AWS_REGION" \
                --image-scanning-configuration scanOnPush=true
            
            # Set lifecycle policy
            aws ecr put-lifecycle-policy \
                --repository-name "$repo" \
                --region "$AWS_REGION" \
                --lifecycle-policy-text '{
                    "rules": [
                        {
                            "rulePriority": 1,
                            "description": "Keep last 10 images",
                            "selection": {
                                "tagStatus": "tagged",
                                "countType": "imageCountMoreThan",
                                "countNumber": 10
                            },
                            "action": {
                                "type": "expire"
                            }
                        }
                    ]
                }'
        fi
    done
    
    log_success "ECR repositories configured"
}

# Create Parameter Store secrets
create_parameter_store_secrets() {
    log_info "Creating Parameter Store secrets..."
    
    local parameters=(
        "/${PROJECT_NAME}/db/password"
        "/${PROJECT_NAME}/firebase/project_id"
        "/${PROJECT_NAME}/firebase/private_key"
        "/${PROJECT_NAME}/firebase/client_email"
        "/${PROJECT_NAME}/gemini/api_key"
    )
    
    for param in "${parameters[@]}"; do
        if aws ssm get-parameter --name "$param" --region "$AWS_REGION" 2>/dev/null; then
            log_warning "Parameter '$param' already exists - skipping"
        else
            log_warning "Parameter '$param' needs to be created manually with actual values"
            echo "aws ssm put-parameter --name '$param' --value 'YOUR_VALUE_HERE' --type SecureString --region $AWS_REGION"
        fi
    done
    
    log_info "Parameter Store setup complete"
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring infrastructure..."
    
    # Create CloudWatch log groups
    local log_groups=(
        "/ecs/${PROJECT_NAME}"
        "/aws/lambda/${PROJECT_NAME}"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$AWS_REGION" | grep -q "$log_group"; then
            log_info "Log group '$log_group' already exists"
        else
            log_info "Creating log group '$log_group'..."
            aws logs create-log-group \
                --log-group-name "$log_group" \
                --region "$AWS_REGION"
            
            # Set retention policy
            aws logs put-retention-policy \
                --log-group-name "$log_group" \
                --retention-in-days 30 \
                --region "$AWS_REGION"
        fi
    done
    
    log_success "Monitoring setup complete"
}

# Create SSL certificate (if domain is configured)
create_ssl_certificate() {
    local domain_name=${DOMAIN_NAME:-""}
    
    if [ -n "$domain_name" ]; then
        log_info "Setting up SSL certificate for $domain_name..."
        
        # Check if certificate already exists
        local cert_arn=$(aws acm list-certificates \
            --region "$AWS_REGION" \
            --query "CertificateSummaryList[?DomainName=='$domain_name'].CertificateArn" \
            --output text)
        
        if [ -n "$cert_arn" ] && [ "$cert_arn" != "None" ]; then
            log_info "SSL certificate already exists: $cert_arn"
        else
            log_info "Requesting SSL certificate for $domain_name..."
            cert_arn=$(aws acm request-certificate \
                --domain-name "$domain_name" \
                --validation-method DNS \
                --region "$AWS_REGION" \
                --query CertificateArn \
                --output text)
            
            log_warning "SSL certificate requested: $cert_arn"
            log_warning "Please complete DNS validation in the AWS Console"
        fi
        
        echo "SSL_CERTIFICATE_ARN=$cert_arn" >> .env.production
    else
        log_info "No domain name configured, skipping SSL certificate setup"
    fi
}

# Setup database backup
setup_database_backup() {
    log_info "Setting up database backup strategy..."
    
    # Create backup role
    local backup_role_name="${PROJECT_NAME}-backup-role"
    
    if aws iam get-role --role-name "$backup_role_name" 2>/dev/null; then
        log_info "Backup role already exists"
    else
        log_info "Creating backup role..."
        aws iam create-role \
            --role-name "$backup_role_name" \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": "backup.amazonaws.com"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }'
        
        aws iam attach-role-policy \
            --role-name "$backup_role_name" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
    fi
    
    log_success "Database backup configured"
}

# Generate configuration files
generate_config_files() {
    log_info "Generating configuration files..."
    
    # Create .env.production if it doesn't exist
    if [ ! -f ".env.production" ]; then
        log_info "Creating .env.production from template..."
        cp .env.production.example .env.production
        
        log_warning "Please update .env.production with your actual values:"
        echo "  - Database password"
        echo "  - Firebase credentials"  
        echo "  - Gemini API key"
        echo "  - Other environment-specific values"
    fi
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f "infrastructure/terraform/terraform.tfvars" ]; then
        log_info "Creating terraform.tfvars from template..."
        cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
        
        # Update ECR repository URLs
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        sed -i.bak "s/123456789012/${account_id}/g" infrastructure/terraform/terraform.tfvars
        rm infrastructure/terraform/terraform.tfvars.bak
        
        log_warning "Please update infrastructure/terraform/terraform.tfvars with your actual values"
    fi
    
    log_success "Configuration files generated"
}

# Main setup function
main() {
    log_info "🚀 Starting ContractorLens production setup..."
    log_info "AWS Region: $AWS_REGION"
    log_info "Project Name: $PROJECT_NAME"
    
    check_prerequisites
    create_terraform_backend
    create_ecr_repositories
    create_parameter_store_secrets
    setup_monitoring
    create_ssl_certificate
    setup_database_backup
    generate_config_files
    
    log_success "✅ Production setup completed!"
    
    echo
    log_info "Next Steps:"
    echo "1. Update .env.production with your actual values"
    echo "2. Update infrastructure/terraform/terraform.tfvars with your configuration"
    echo "3. Set the required Parameter Store values:"
    echo "   aws ssm put-parameter --name '/${PROJECT_NAME}/db/password' --value 'YOUR_DB_PASSWORD' --type SecureString"
    echo "   aws ssm put-parameter --name '/${PROJECT_NAME}/firebase/project_id' --value 'YOUR_FIREBASE_PROJECT' --type SecureString"
    echo "   aws ssm put-parameter --name '/${PROJECT_NAME}/gemini/api_key' --value 'YOUR_GEMINI_KEY' --type SecureString"
    echo "4. Run the deployment: ./scripts/deploy.sh"
    echo
    log_info "For monitoring setup: docker-compose -f monitoring/docker-compose.monitoring.yml up -d"
}

main "$@"