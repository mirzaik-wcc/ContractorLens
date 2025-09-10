# ContractorLens Production Operations Manual

## 🎯 Overview

This manual provides comprehensive operational procedures for maintaining and troubleshooting the ContractorLens production environment.

## 📋 Table of Contents

1. [System Architecture](#system-architecture)
2. [Deployment Procedures](#deployment-procedures)
3. [Monitoring & Alerting](#monitoring--alerting)
4. [Incident Response](#incident-response)
5. [Maintenance Tasks](#maintenance-tasks)
6. [Disaster Recovery](#disaster-recovery)
7. [Security Procedures](#security-procedures)
8. [Troubleshooting Guide](#troubleshooting-guide)

## 🏗️ System Architecture

### Production Environment
- **Infrastructure**: AWS ECS Fargate with Application Load Balancer
- **Database**: Amazon RDS PostgreSQL 15
- **Container Registry**: Amazon ECR
- **Monitoring**: CloudWatch + Prometheus + Grafana
- **SSL/TLS**: AWS Certificate Manager
- **DNS**: Route 53 (if configured)

### Service Components
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │  Load Balancer  │    │  ECS Fargate    │
│                 │────│     (ALB)       │────│   Backend       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                               ┌─────────────────┐
                                               │  Gemini Service │
                                               │     (ML)        │
                                               └─────────────────┘
                                                        │
                                               ┌─────────────────┐
                                               │   PostgreSQL    │
                                               │      RDS        │
                                               └─────────────────┘
```

### Key URLs and Endpoints
- **Production API**: `https://api.contractorlens.com` (if custom domain configured)
- **Health Check**: `/health`
- **API Documentation**: `/api/v1/docs`
- **Monitoring Dashboard**: Grafana on port 3001
- **Prometheus Metrics**: Port 9090

## 🚀 Deployment Procedures

### Standard Deployment Process

1. **Pre-deployment Checklist**
   ```bash
   # Check system health
   curl -f https://api.contractorlens.com/health
   
   # Verify database connectivity
   aws rds describe-db-instances --db-instance-identifier contractorlens-db
   
   # Check ECS service status
   aws ecs describe-services --cluster contractorlens --services contractorlens
   ```

2. **Execute Deployment**
   ```bash
   # Run the deployment script
   ./scripts/deploy.sh production
   
   # Monitor deployment progress
   aws ecs wait services-stable --cluster contractorlens --services contractorlens
   ```

3. **Post-deployment Verification**
   ```bash
   # Health checks
   ./scripts/deploy.sh health-check
   
   # Monitor logs for errors
   aws logs tail /ecs/contractorlens --follow
   ```

### Emergency Rollback Procedure

```bash
# Quick rollback to previous version
./scripts/deploy.sh rollback

# Manual rollback using AWS CLI
aws ecs update-service \
  --cluster contractorlens \
  --service contractorlens \
  --task-definition contractorlens:PREVIOUS_REVISION
```

## 📊 Monitoring & Alerting

### Key Metrics to Monitor

#### Application Metrics
- **API Response Time**: < 2 seconds (95th percentile)
- **Error Rate**: < 1% of total requests
- **Request Throughput**: Baseline ~10-50 requests/minute
- **Active ECS Tasks**: >= 2 running tasks

#### Infrastructure Metrics
- **Database CPU**: < 80% utilization
- **Database Connections**: < 15 active connections
- **ECS CPU/Memory**: < 70% utilization
- **Load Balancer Health**: All targets healthy

#### Business Metrics
- **Estimates Generated**: > 5 per hour during business hours
- **Gemini API Latency**: < 10 seconds average
- **User Sessions**: Track daily/monthly active users

### Alerting Channels

1. **Critical Alerts** (Immediate Response)
   - Email: `devops@contractorlens.com`
   - SMS: Primary on-call engineer
   - Slack: `#alerts-critical`

2. **Warning Alerts** (Monitor Closely)
   - Email: `team@contractorlens.com`
   - Slack: `#alerts-warning`

### Dashboard Access

- **Production Dashboard**: `http://grafana-server:3001/d/contractorlens-prod`
- **CloudWatch Console**: AWS Console > CloudWatch > Dashboards > ContractorLens
- **ECS Console**: AWS Console > ECS > contractorlens cluster

## 🚨 Incident Response

### Severity Levels

#### P0 - Critical (Response: Immediate)
- Complete service outage
- Database failure
- Security breach
- Data corruption

#### P1 - High (Response: < 15 minutes)
- High error rates (>5%)
- Severe performance degradation
- Authentication failures
- Key feature outages

#### P2 - Medium (Response: < 1 hour)
- Moderate performance issues
- Non-critical feature problems
- Warning thresholds exceeded

#### P3 - Low (Response: Next business day)
- Minor bugs
- Feature requests
- Documentation updates

### Incident Response Procedures

1. **Immediate Response (First 5 minutes)**
   ```bash
   # Check overall system health
   curl -f https://api.contractorlens.com/health
   
   # Check ECS service status
   aws ecs describe-services --cluster contractorlens --services contractorlens
   
   # Check recent logs
   aws logs tail /ecs/contractorlens --since 10m
   ```

2. **Assessment (5-15 minutes)**
   - Identify affected components
   - Determine user impact
   - Assess if rollback is needed
   - Notify stakeholders

3. **Mitigation Actions**
   ```bash
   # Scale up ECS service if needed
   aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 4
   
   # Restart service if necessary
   aws ecs update-service --cluster contractorlens --service contractorlens --force-new-deployment
   
   # Emergency rollback
   ./scripts/deploy.sh rollback
   ```

### Common Incident Types

#### High Error Rate
1. **Check Logs**: Look for specific error patterns
2. **Database**: Verify connection pool and query performance
3. **Gemini API**: Check API quotas and latency
4. **Rollback**: If errors started after deployment

#### Service Unavailable
1. **ECS Health**: Check task health and ALB targets
2. **Database**: Verify RDS instance status
3. **Network**: Check security groups and subnets
4. **Scale**: Increase task count if capacity issue

#### Database Issues
1. **Connections**: Monitor active connection count
2. **Performance**: Check slow query logs
3. **Storage**: Verify available disk space
4. **Backup**: Ensure recent backups are available

## 🔧 Maintenance Tasks

### Daily Tasks
- [ ] Check system health dashboard
- [ ] Review error rates and logs
- [ ] Monitor resource utilization
- [ ] Verify backup completion

### Weekly Tasks
- [ ] Review security alerts and patches
- [ ] Analyze performance trends
- [ ] Update capacity planning
- [ ] Test alerting mechanisms

### Monthly Tasks
- [ ] Security audit and review
- [ ] Cost optimization review
- [ ] Disaster recovery test
- [ ] Update documentation

### Quarterly Tasks
- [ ] Full disaster recovery drill
- [ ] Infrastructure security scan
- [ ] Performance baseline update
- [ ] Business continuity review

## 💾 Disaster Recovery

### Recovery Time Objectives (RTO)
- **Database Recovery**: 2 hours
- **Application Recovery**: 30 minutes
- **Full System Recovery**: 4 hours

### Recovery Point Objectives (RPO)
- **Database**: 15 minutes (continuous backups)
- **Configuration**: Daily (Infrastructure as Code)

### Recovery Procedures

#### Database Recovery
```bash
# List available backups
aws rds describe-db-snapshots --db-instance-identifier contractorlens-db

# Restore from backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier contractorlens-db-restored \
  --db-snapshot-identifier contractorlens-db-snapshot-YYYYMMDD
```

#### Infrastructure Recovery
```bash
# Restore infrastructure from Terraform
cd infrastructure/terraform
terraform init
terraform plan
terraform apply

# Redeploy application
./scripts/deploy.sh production
```

#### Cross-Region Recovery (if configured)
```bash
# Switch to DR region
export AWS_REGION=us-east-1

# Deploy infrastructure in DR region
cd infrastructure/terraform
terraform workspace select dr
terraform apply

# Update DNS to point to DR region
```

## 🔐 Security Procedures

### Access Control
- **AWS Console**: IAM roles with least privilege
- **SSH Access**: EC2 Instance Connect (no persistent keys)
- **Database**: VPC private subnets only
- **API**: Firebase authentication required

### Security Monitoring
```bash
# Check for failed login attempts
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "FAILED_LOGIN"

# Review security groups
aws ec2 describe-security-groups \
  --group-names contractorlens-app-sg contractorlens-alb-sg
```

### Certificate Management
```bash
# Check certificate expiration
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:region:account:certificate/cert-id

# Renew certificates (automatic with ACM, but verify)
aws acm list-certificates --certificate-statuses EXPIRED,PENDING_VALIDATION
```

## 🔍 Troubleshooting Guide

### Common Issues and Solutions

#### "Service Unavailable" Error
```bash
# Check ECS service health
aws ecs describe-services --cluster contractorlens --services contractorlens

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn TARGET_GROUP_ARN

# Solution: Scale up or restart service
aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 3
```

#### High Response Times
```bash
# Check database performance
aws rds describe-db-instances --db-instance-identifier contractorlens-db

# Check slow queries
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "slow query"

# Solutions:
# 1. Scale database instance
# 2. Optimize queries
# 3. Add database indexes
# 4. Scale ECS service
```

#### Gemini API Failures
```bash
# Check API quotas and limits
curl -H "Authorization: Bearer $GEMINI_API_KEY" \
  https://generativelanguage.googleapis.com/v1/models

# Check service logs for API errors
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "GeminiAPI ERROR"

# Solutions:
# 1. Check API key validity
# 2. Verify quota limits
# 3. Implement retry logic
# 4. Use fallback mode
```

#### Database Connection Issues
```bash
# Check database status
aws rds describe-db-instances --db-instance-identifier contractorlens-db

# Check connection pool
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "connection pool"

# Solutions:
# 1. Restart ECS tasks
# 2. Check security groups
# 3. Verify database credentials in Parameter Store
# 4. Scale database connections
```

## 📞 Emergency Contacts

- **Primary On-Call**: [Your primary contact]
- **Secondary On-Call**: [Your secondary contact]
- **AWS Support**: [Your AWS support plan details]
- **Google Cloud Support**: [For Gemini API issues]

## 📚 Additional Resources

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **ECS Best Practices**: https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Prometheus Monitoring**: https://prometheus.io/docs/

---

**Last Updated**: $(date)  
**Document Version**: 1.0  
**Maintained By**: DevOps Team