# ContractorLens Disaster Recovery Plan

## 🎯 Executive Summary

This document outlines the disaster recovery procedures for ContractorLens production systems to ensure business continuity in case of system failures, natural disasters, or security incidents.

## 📊 Recovery Objectives

### Recovery Time Objective (RTO)
- **Critical Systems**: 2 hours
- **Database Recovery**: 2 hours  
- **Application Services**: 30 minutes
- **Full Service Restoration**: 4 hours

### Recovery Point Objective (RPO)
- **Database Data Loss**: Maximum 15 minutes
- **Configuration Changes**: Maximum 24 hours
- **Application Code**: Zero loss (version controlled)

### Business Impact Tolerances
- **Revenue Impact**: $1,000/hour downtime
- **User Impact**: Up to 10,000 affected users
- **Reputation Impact**: Social media monitoring required

## 🏗️ System Architecture Overview

### Production Components
```
Internet
    │
    ▼
┌─────────────┐
│     ALB     │ ◄── SSL Termination
└─────────────┘
    │
    ▼
┌─────────────┐
│ ECS Fargate │ ◄── Backend API
│   Cluster   │
└─────────────┘
    │
    ▼
┌─────────────┐
│ PostgreSQL  │ ◄── Primary Database
│     RDS     │
└─────────────┘
```

### Critical Dependencies
- **AWS Region**: us-west-2 (primary)
- **Backup Region**: us-east-1 (disaster recovery)
- **External APIs**: Google Gemini, Firebase Auth
- **DNS Provider**: Route 53
- **Monitoring**: CloudWatch, Prometheus

## 🚨 Disaster Scenarios

### Scenario 1: Complete AWS Region Failure

**Probability**: Low  
**Impact**: Critical  
**RTO**: 4 hours  
**RPO**: 15 minutes

#### Detection
- CloudWatch alarms across all services
- Application completely unreachable
- AWS Status Page confirms regional issues

#### Response Procedure
1. **Immediate Assessment** (0-15 minutes)
   ```bash
   # Check AWS service status
   curl -s https://status.aws.amazon.com/
   
   # Verify multi-region impact
   aws --region us-east-1 ec2 describe-regions
   ```

2. **Activate DR Region** (15-60 minutes)
   ```bash
   # Switch to DR region
   export AWS_REGION=us-east-1
   
   # Deploy infrastructure in DR region
   cd infrastructure/terraform
   terraform workspace select disaster-recovery
   terraform apply -auto-approve
   ```

3. **Database Restoration** (60-120 minutes)
   ```bash
   # Restore from latest cross-region backup
   aws rds restore-db-instance-from-db-snapshot \
     --region us-east-1 \
     --db-instance-identifier contractorlens-db-dr \
     --db-snapshot-identifier contractorlens-db-snapshot-latest
   ```

4. **Application Deployment** (120-150 minutes)
   ```bash
   # Deploy application in DR region
   ./scripts/deploy.sh disaster-recovery
   ```

5. **DNS Failover** (150-180 minutes)
   ```bash
   # Update Route 53 records to point to DR region
   aws route53 change-resource-record-sets \
     --hosted-zone-id Z123456789 \
     --change-batch file://dns-failover.json
   ```

### Scenario 2: Database Failure/Corruption

**Probability**: Medium  
**Impact**: Critical  
**RTO**: 2 hours  
**RPO**: 15 minutes

#### Detection
- Database connection failures
- Data inconsistency alerts
- Application 500 errors

#### Response Procedure
1. **Immediate Isolation** (0-5 minutes)
   ```bash
   # Stop application writes to prevent further corruption
   aws ecs update-service \
     --cluster contractorlens \
     --service contractorlens \
     --desired-count 0
   ```

2. **Assess Damage** (5-15 minutes)
   ```bash
   # Check database status
   aws rds describe-db-instances --db-instance-identifier contractorlens-db
   
   # Review recent backups
   aws rds describe-db-snapshots \
     --db-instance-identifier contractorlens-db \
     --max-records 10
   ```

3. **Database Recovery** (15-120 minutes)
   ```bash
   # Point-in-time recovery
   aws rds restore-db-instance-to-point-in-time \
     --target-db-instance-identifier contractorlens-db-restored \
     --source-db-instance-identifier contractorlens-db \
     --restore-time 2024-01-15T10:30:00Z
   ```

4. **Validation and Restart** (120-135 minutes)
   ```bash
   # Validate database integrity
   psql -h restored-endpoint -c "SELECT count(*) FROM items;"
   
   # Update connection strings and restart application
   aws ecs update-service \
     --cluster contractorlens \
     --service contractorlens \
     --desired-count 2
   ```

### Scenario 3: Security Breach/Compromise

**Probability**: Medium  
**Impact**: Critical  
**RTO**: 1 hour  
**RPO**: 0 minutes

#### Detection
- Security monitoring alerts
- Unusual access patterns
- Data exfiltration indicators
- External security notifications

#### Response Procedure
1. **Immediate Containment** (0-5 minutes)
   ```bash
   # Isolate compromised systems
   aws ec2 modify-security-group-rules \
     --group-id sg-compromised \
     --security-group-rules Type=ingress,IpProtocol=-1,CidrIpv4=0.0.0.0/0,Description="Block all inbound"
   ```

2. **Revoke Access** (5-15 minutes)
   ```bash
   # Rotate all secrets immediately
   aws ssm put-parameter \
     --name "/contractorlens/db/password" \
     --value "new-secure-password" \
     --type SecureString \
     --overwrite
   
   # Disable compromised API keys
   # (Firebase console, Gemini console)
   ```

3. **System Rebuild** (15-60 minutes)
   ```bash
   # Deploy fresh infrastructure
   cd infrastructure/terraform
   terraform destroy -auto-approve
   terraform apply -auto-approve
   
   # Deploy from known-good code base
   git checkout main
   ./scripts/deploy.sh production
   ```

### Scenario 4: Application Service Failure

**Probability**: High  
**Impact**: High  
**RTO**: 30 minutes  
**RPO**: 0 minutes

#### Detection
- Health check failures
- High error rates
- User reports of service unavailability

#### Response Procedure
1. **Quick Assessment** (0-2 minutes)
   ```bash
   # Check ECS service health
   aws ecs describe-services --cluster contractorlens --services contractorlens
   
   # Check load balancer targets
   aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
   ```

2. **Immediate Mitigation** (2-10 minutes)
   ```bash
   # Scale up healthy instances
   aws ecs update-service \
     --cluster contractorlens \
     --service contractorlens \
     --desired-count 4
   
   # Force new deployment if needed
   aws ecs update-service \
     --cluster contractorlens \
     --service contractorlens \
     --force-new-deployment
   ```

3. **Rollback if Necessary** (10-30 minutes)
   ```bash
   # Rollback to previous working version
   ./scripts/deploy.sh rollback
   ```

## 🔄 Backup Strategies

### Database Backups
```bash
# Automated daily backups (enabled in RDS)
aws rds describe-db-instances \
  --db-instance-identifier contractorlens-db \
  --query 'DBInstances[0].BackupRetentionPeriod'

# Cross-region backup replication
aws rds create-db-snapshot \
  --db-instance-identifier contractorlens-db \
  --db-snapshot-identifier contractorlens-$(date +%Y%m%d-%H%M%S)

aws rds copy-db-snapshot \
  --source-db-snapshot-identifier contractorlens-snapshot \
  --target-db-snapshot-identifier contractorlens-snapshot-dr \
  --source-region us-west-2 \
  --target-region us-east-1
```

### Configuration Backups
```bash
# Infrastructure as Code (Terraform state)
# - Stored in S3 with versioning
# - Cross-region replication enabled
# - Version controlled in Git

# Application configuration
# - Environment variables in Parameter Store
# - Docker images in ECR with lifecycle policies
# - Code in Git repositories with tags
```

### Monitoring Data Retention
- **CloudWatch Logs**: 30 days retention
- **Metrics**: 15 months retention
- **Prometheus**: 30 days local, long-term in Grafana Cloud

## 🧪 Testing Procedures

### Monthly DR Tests
```bash
#!/bin/bash
# Monthly DR test script
echo "Starting DR test..."

# Test backup restoration
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier contractorlens-db-test \
  --db-snapshot-identifier contractorlens-db-snapshot-latest

# Test application deployment in DR region
export AWS_REGION=us-east-1
./scripts/deploy.sh staging

# Verify functionality
curl -f https://staging.contractorlens.com/health

# Cleanup test resources
aws rds delete-db-instance \
  --db-instance-identifier contractorlens-db-test \
  --skip-final-snapshot
```

### Quarterly Full DR Drill
1. **Pre-drill Preparation**
   - Notify all stakeholders
   - Schedule maintenance window
   - Prepare rollback procedures

2. **Drill Execution**
   - Simulate primary region failure
   - Execute full DR procedures
   - Validate all systems operational
   - Test user workflows end-to-end

3. **Post-drill Analysis**
   - Document lessons learned
   - Update procedures as needed
   - Report on RTO/RPO compliance

## 📞 Communication Plan

### Internal Communication
1. **Incident Detection** → DevOps Team (immediate)
2. **Severity Assessment** → Engineering Lead (5 minutes)
3. **Business Impact** → Product Owner (15 minutes)
4. **Executive Summary** → C-Level (30 minutes)

### External Communication
1. **User Notification**
   ```bash
   # Status page update
   # Email to affected users
   # Social media updates
   # Customer support briefing
   ```

2. **Partner Notification**
   ```bash
   # Firebase/Google Cloud
   # AWS Support (if using Business/Enterprise)
   # Third-party integrations
   ```

## 📋 Recovery Validation Checklist

### System Functionality Tests
- [ ] Health endpoints responding (200 OK)
- [ ] Database connectivity confirmed
- [ ] API endpoints functional
- [ ] Authentication working
- [ ] Gemini integration operational
- [ ] Load balancer routing correctly

### Performance Validation
- [ ] Response times within SLA (<2 seconds)
- [ ] Error rates below threshold (<1%)
- [ ] Database query performance normal
- [ ] Resource utilization reasonable

### Security Verification
- [ ] SSL certificates valid
- [ ] Access controls enforced
- [ ] API keys rotated if compromised
- [ ] Security groups properly configured
- [ ] Audit logging functional

### Business Function Tests
- [ ] User registration/login
- [ ] AR scanning workflow
- [ ] Estimate generation
- [ ] Cost calculations accurate
- [ ] Report generation
- [ ] Data integrity verified

## 📊 Recovery Metrics

### Track and Report
- **Actual RTO vs Target**: Compare actual recovery time to 4-hour target
- **Actual RPO vs Target**: Compare data loss to 15-minute target  
- **System Availability**: Calculate uptime percentage
- **User Impact**: Number of users affected and duration
- **Business Impact**: Revenue lost during outage
- **Recovery Cost**: Resources used during DR activities

### Continuous Improvement
- Monthly review of DR procedures
- Update based on infrastructure changes
- Training for new team members
- Regular testing and validation
- Documentation updates

## 🔐 Security Considerations

### Access Control During DR
- Emergency access procedures
- Break-glass authentication
- Audit trail requirements
- Principle of least privilege maintained

### Data Protection
- Encryption at rest and in transit
- Secure backup storage
- Access logging
- Compliance requirements (if applicable)

---

**Document Owner**: DevOps Team  
**Last Updated**: $(date)  
**Review Frequency**: Quarterly  
**Next Review**: $(date -d "+3 months" +%Y-%m-%d)