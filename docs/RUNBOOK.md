# ContractorLens Production Runbook

## 🎯 Quick Reference

### Emergency Contacts
- **Primary On-Call**: [Insert Contact]
- **Secondary On-Call**: [Insert Contact]  
- **AWS Support**: [Insert Support Case Link]
- **Escalation Manager**: [Insert Contact]

### Critical URLs
- **Production API**: https://api.contractorlens.com
- **Health Check**: https://api.contractorlens.com/health
- **Grafana Dashboard**: http://monitoring-server:3001
- **AWS Console**: https://us-west-2.console.aws.amazon.com/ecs/

### Quick Commands
```bash
# Check system health
curl -f https://api.contractorlens.com/health

# Scale ECS service
aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 4

# Emergency rollback
./scripts/deploy.sh rollback

# View live logs
aws logs tail /ecs/contractorlens --follow
```

## 🚨 Alert Response Procedures

### P0: Service Down (Critical - Immediate Response)

#### Symptoms
- Health check returning 5xx errors
- No response from load balancer
- ECS service showing 0 running tasks

#### Immediate Actions (First 5 minutes)
```bash
# 1. Check ECS service status
aws ecs describe-services --cluster contractorlens --services contractorlens

# 2. Check load balancer health
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names contractorlens-app-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# 3. Check recent deployments
aws ecs list-tasks --cluster contractorlens --service-name contractorlens

# 4. Scale up if tasks are failing
aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 4
```

#### Investigation Steps
1. **Check Application Logs**
   ```bash
   aws logs tail /ecs/contractorlens --follow --since 15m
   ```

2. **Database Connectivity**
   ```bash
   # Check database status
   aws rds describe-db-instances --db-instance-identifier contractorlens-db
   
   # Test connection from ECS task
   aws ecs execute-command \
     --cluster contractorlens \
     --task TASK_ID \
     --container backend \
     --command "pg_isready -h DB_HOST -p 5432"
   ```

3. **External Dependencies**
   ```bash
   # Test Gemini API
   curl -H "Authorization: Bearer $GEMINI_API_KEY" \
     https://generativelanguage.googleapis.com/v1/models
   
   # Test Firebase
   curl -f https://firebase.googleapis.com/
   ```

#### Resolution Actions
- **If deployment caused issue**: Rollback immediately
- **If database issue**: Scale read replicas, check for locks
- **If infrastructure issue**: Scale ECS service, check ALB
- **If external API issue**: Enable fallback mode

### P1: High Error Rate (High - Response < 15 minutes)

#### Symptoms
- Error rate > 5% of total requests
- 4xx/5xx errors increasing rapidly
- User reports of failed operations

#### Investigation
```bash
# Check error patterns in logs
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "ERROR" \
  --start-time $(date -d '15 minutes ago' +%s)000

# Check specific API endpoints
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "[timestamp, request_id, level=ERROR, ...]" \
  --start-time $(date -d '15 minutes ago' +%s)000
```

#### Common Causes & Solutions
1. **Database Connection Pool Exhaustion**
   ```bash
   # Check active connections
   aws logs filter-log-events \
     --log-group-name /ecs/contractorlens \
     --filter-pattern "connection pool"
   
   # Solution: Restart ECS tasks to reset connections
   aws ecs update-service --cluster contractorlens --service contractorlens --force-new-deployment
   ```

2. **Gemini API Rate Limiting**
   ```bash
   # Check for rate limit errors
   aws logs filter-log-events \
     --log-group-name /ecs/contractorlens \
     --filter-pattern "rate limit"
   
   # Solution: Enable degraded mode without ML features
   aws ssm put-parameter \
     --name "/contractorlens/feature-flags/ml-enabled" \
     --value "false" \
     --overwrite
   ```

3. **Memory Pressure**
   ```bash
   # Check ECS task memory utilization
   aws ecs describe-services --cluster contractorlens --services contractorlens
   
   # Solution: Scale up ECS service
   aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 4
   ```

### P1: High Response Time (High - Response < 15 minutes)

#### Symptoms
- 95th percentile response time > 5 seconds
- Users reporting slow estimates
- Timeout errors increasing

#### Investigation
```bash
# Check slow queries in database
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "[timestamp, request_id, level, duration > 5000]"

# Check Gemini API latency
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "GeminiAPI" \
  --start-time $(date -d '15 minutes ago' +%s)000
```

#### Resolution Actions
1. **Database Performance Issue**
   ```bash
   # Check for blocking queries
   aws rds describe-db-log-files --db-instance-identifier contractorlens-db
   
   # Scale database if needed
   aws rds modify-db-instance \
     --db-instance-identifier contractorlens-db \
     --db-instance-class db.t3.large \
     --apply-immediately
   ```

2. **Application Performance**
   ```bash
   # Scale ECS service
   aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 6
   
   # Check for memory/CPU constraints
   aws ecs describe-tasks --cluster contractorlens --tasks $(aws ecs list-tasks --cluster contractorlens --service-name contractorlens --query 'taskArns[0]' --output text)
   ```

### P2: Warning Thresholds (Medium - Response < 1 hour)

#### High Resource Utilization
```bash
# Check ECS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=contractorlens Name=ClusterName,Value=contractorlens \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### Database Connection Warnings
```bash
# Monitor connection count
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=contractorlens-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## 🔧 Common Maintenance Tasks

### Deployment
```bash
# Standard deployment
./scripts/deploy.sh production

# Check deployment status
aws ecs wait services-stable --cluster contractorlens --services contractorlens

# Monitor deployment
watch -n 10 'aws ecs describe-services --cluster contractorlens --services contractorlens --query "services[0].deployments"'
```

### Scaling Operations
```bash
# Scale ECS service up
aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 4

# Scale ECS service down (during low traffic)
aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 2

# Check current scaling
aws ecs describe-services --cluster contractorlens --services contractorlens --query 'services[0].[desiredCount,runningCount,pendingCount]'
```

### Database Maintenance
```bash
# Create manual backup
aws rds create-db-snapshot \
  --db-instance-identifier contractorlens-db \
  --db-snapshot-identifier manual-backup-$(date +%Y%m%d-%H%M%S)

# Check backup status
aws rds describe-db-snapshots --db-instance-identifier contractorlens-db --max-records 5

# Database connection check
aws ecs execute-command \
  --cluster contractorlens \
  --task $(aws ecs list-tasks --cluster contractorlens --service-name contractorlens --query 'taskArns[0]' --output text) \
  --container backend \
  --command "psql -h $DB_HOST -U $DB_USER -c 'SELECT version();'"
```

### Log Management
```bash
# Search for specific errors
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "ERROR estimate generation failed" \
  --start-time $(date -d '1 hour ago' +%s)000

# Export logs for analysis
aws logs create-export-task \
  --log-group-name /ecs/contractorlens \
  --from $(date -d '1 day ago' +%s)000 \
  --to $(date +%s)000 \
  --destination contractorlens-logs-export
```

## 📊 Monitoring & Diagnostics

### Health Check Commands
```bash
# Application health
curl -f https://api.contractorlens.com/health

# API functionality test
curl -X POST https://api.contractorlens.com/api/v1/estimates \
  -H "Content-Type: application/json" \
  -d '{"room_type":"kitchen","dimensions":{"length":10,"width":10,"height":8},"location":{"zip_code":"94105"}}'

# Database health from application
curl -f https://api.contractorlens.com/api/v1/health/database
```

### Performance Monitoring
```bash
# Check current load
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/contractorlens-alb/$(aws elbv2 describe-load-balancers --names contractorlens-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check response times
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/contractorlens-alb/$(aws elbv2 describe-load-balancers --names contractorlens-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text | cut -d'/' -f2-) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Resource Utilization
```bash
# ECS CPU/Memory
aws ecs describe-services --cluster contractorlens --services contractorlens --query 'services[0].deployments[0].{TaskDefinition:taskDefinition,DesiredCount:desiredCount,RunningCount:runningCount}'

# Database metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=contractorlens-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## 🔄 Recovery Procedures

### Application Recovery
```bash
# Restart all ECS tasks
aws ecs update-service --cluster contractorlens --service contractorlens --force-new-deployment

# Rollback to previous version
./scripts/deploy.sh rollback

# Manual task restart
for task in $(aws ecs list-tasks --cluster contractorlens --service-name contractorlens --query 'taskArns[]' --output text); do
  aws ecs stop-task --cluster contractorlens --task $task
done
```

### Database Recovery
```bash
# Point-in-time recovery
aws rds restore-db-instance-to-point-in-time \
  --target-db-instance-identifier contractorlens-db-restored \
  --source-db-instance-identifier contractorlens-db \
  --restore-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier contractorlens-db-restored \
  --db-snapshot-identifier contractorlens-db-snapshot-$(date +%Y%m%d)
```

## 📈 Performance Tuning

### Database Optimization
```bash
# Check slow queries
aws rds describe-db-log-files --db-instance-identifier contractorlens-db

# Connection pooling check
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "pool"

# Index usage analysis
aws ecs execute-command \
  --cluster contractorlens \
  --task $(aws ecs list-tasks --cluster contractorlens --service-name contractorlens --query 'taskArns[0]' --output text) \
  --container backend \
  --command "psql -h $DB_HOST -U $DB_USER -c 'SELECT schemaname,tablename,indexname,idx_tup_read,idx_tup_fetch FROM pg_stat_user_indexes ORDER BY idx_tup_read DESC LIMIT 10;'"
```

### Application Performance
```bash
# Memory usage analysis
aws ecs describe-tasks \
  --cluster contractorlens \
  --tasks $(aws ecs list-tasks --cluster contractorlens --service-name contractorlens --query 'taskArns[]' --output text)

# Scale based on load
current_tasks=$(aws ecs describe-services --cluster contractorlens --services contractorlens --query 'services[0].runningCount')
if [ $current_tasks -lt 3 ]; then
  aws ecs update-service --cluster contractorlens --service contractorlens --desired-count 3
fi
```

## 🔐 Security Procedures

### Access Review
```bash
# Check recent API access
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "[timestamp, request_id, level, method, path, status >= 200]" \
  --start-time $(date -d '1 hour ago' +%s)000

# Review failed authentication
aws logs filter-log-events \
  --log-group-name /ecs/contractorlens \
  --filter-pattern "authentication failed" \
  --start-time $(date -d '24 hours ago' +%s)000
```

### Secret Rotation
```bash
# Rotate database password
new_password=$(openssl rand -base64 32)
aws ssm put-parameter \
  --name "/contractorlens/db/password" \
  --value "$new_password" \
  --type SecureString \
  --overwrite

# Force ECS service to pick up new secrets
aws ecs update-service --cluster contractorlens --service contractorlens --force-new-deployment
```

## 📋 Pre-flight Checklist

### Before Deployment
- [ ] Verify backup completion in last 24 hours
- [ ] Check system health dashboards
- [ ] Confirm low traffic period
- [ ] Test staging environment
- [ ] Prepare rollback plan
- [ ] Notify team of deployment window

### After Deployment  
- [ ] Verify health endpoints respond correctly
- [ ] Check error rates in first 15 minutes
- [ ] Monitor response times
- [ ] Verify database connectivity
- [ ] Test critical user workflows
- [ ] Update deployment documentation

---

**Document Owner**: DevOps Team  
**Emergency Contact**: [Insert 24/7 contact]  
**Last Updated**: $(date)  
**Version**: 1.0