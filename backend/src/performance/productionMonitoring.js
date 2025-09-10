/**
 * Production Performance Monitoring System
 * Performance Engineer: PERF001 - Phase 5 Production Monitoring
 * Target: Real-time performance tracking and alerting
 * Created: 2025-09-05
 */

const EventEmitter = require('events');
const os = require('os');
const { performance } = require('perf_hooks');
const fs = require('fs').promises;
const path = require('path');

/**
 * Comprehensive production monitoring system for ContractorLens
 * Tracks performance, alerts on issues, and provides optimization recommendations
 */
class ProductionMonitor extends EventEmitter {
  constructor() {
    super();
    
    this.config = {
      updateInterval: 30000,        // 30 second updates
      alertThresholds: {
        responseTime: 3000,         // 3s max response time
        errorRate: 0.05,            // 5% max error rate
        memoryUsage: 0.85,          // 85% max memory usage
        cpuUsage: 0.80,             // 80% max CPU usage
        diskUsage: 0.90,            // 90% max disk usage
        concurrentConnections: 100,  // 100 max concurrent connections
        queueLength: 50             // 50 max request queue length
      },
      retention: {
        metrics: 7 * 24 * 60 * 60 * 1000,    // 7 days
        alerts: 30 * 24 * 60 * 60 * 1000,    // 30 days
        performanceReports: 90 * 24 * 60 * 60 * 1000  // 90 days
      }
    };

    // Monitoring state
    this.isMonitoring = false;
    this.monitoringTimer = null;
    this.metricsHistory = [];
    this.alertHistory = [];
    this.activeAlerts = new Map();
    
    // Performance tracking
    this.requestMetrics = {
      total: 0,
      successful: 0,
      failed: 0,
      averageResponseTime: 0,
      totalResponseTime: 0,
      lastResetTime: Date.now()
    };

    // System metrics
    this.systemMetrics = {
      uptime: 0,
      memoryUsage: 0,
      cpuUsage: 0,
      diskUsage: 0,
      networkConnections: 0,
      timestamp: Date.now()
    };

    console.log('🔍 Production Monitor initialized');
  }

  // MARK: - Monitoring Control

  startMonitoring() {
    if (this.isMonitoring) {
      console.log('⚠️  Monitoring already active');
      return;
    }

    this.isMonitoring = true;
    
    // Start periodic metric collection
    this.monitoringTimer = setInterval(() => {
      this.collectMetrics();
    }, this.config.updateInterval);

    // Set up request tracking middleware
    this.setupRequestTracking();

    // Set up system monitoring
    this.setupSystemMonitoring();

    console.log('🚀 Production monitoring started');
    this.emit('monitoring_started');
  }

  stopMonitoring() {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;
    
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = null;
    }

    console.log('🛑 Production monitoring stopped');
    this.emit('monitoring_stopped');
  }

  // MARK: - Metric Collection

  async collectMetrics() {
    try {
      const timestamp = Date.now();
      
      // Collect system metrics
      const systemMetrics = await this.collectSystemMetrics();
      
      // Collect application metrics
      const appMetrics = this.collectApplicationMetrics();
      
      // Collect database metrics
      const dbMetrics = await this.collectDatabaseMetrics();
      
      // Combine all metrics
      const metrics = {
        timestamp,
        system: systemMetrics,
        application: appMetrics,
        database: dbMetrics,
        performance: this.calculatePerformanceMetrics()
      };

      // Store metrics
      this.storeMetrics(metrics);
      
      // Check for alerts
      this.checkAlerts(metrics);
      
      // Emit metrics event for real-time monitoring
      this.emit('metrics_collected', metrics);
      
    } catch (error) {
      console.error('❌ Failed to collect metrics:', error);
      this.emit('metric_collection_error', error);
    }
  }

  async collectSystemMetrics() {
    const memoryUsage = process.memoryUsage();
    const totalMemory = os.totalmem();
    const freeMemory = os.freemem();
    
    return {
      uptime: process.uptime(),
      memory: {
        heapUsed: memoryUsage.heapUsed,
        heapTotal: memoryUsage.heapTotal,
        external: memoryUsage.external,
        rss: memoryUsage.rss,
        usagePercentage: ((totalMemory - freeMemory) / totalMemory) * 100
      },
      cpu: {
        usage: await this.getCPUUsage(),
        loadAverage: os.loadavg()
      },
      network: {
        connections: await this.getActiveConnections()
      },
      platform: {
        nodeVersion: process.version,
        platform: os.platform(),
        arch: os.arch(),
        hostname: os.hostname()
      }
    };
  }

  collectApplicationMetrics() {
    const now = Date.now();
    const timeSinceLastReset = now - this.requestMetrics.lastResetTime;
    
    return {
      requests: {
        total: this.requestMetrics.total,
        successful: this.requestMetrics.successful,
        failed: this.requestMetrics.failed,
        errorRate: this.requestMetrics.total > 0 ? this.requestMetrics.failed / this.requestMetrics.total : 0,
        averageResponseTime: this.requestMetrics.averageResponseTime,
        throughput: timeSinceLastReset > 0 ? (this.requestMetrics.total / (timeSinceLastReset / 1000)) : 0
      },
      cache: this.getCacheMetrics(),
      queues: this.getQueueMetrics()
    };
  }

  async collectDatabaseMetrics() {
    const db = require('../config/database');
    
    try {
      // Get database performance stats
      const result = await db.query(`
        SELECT 
          (SELECT json_agg(row_to_json(t)) FROM (SELECT * FROM contractorlens.quick_performance_check()) t) as performance_check,
          (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'contractorlens') as active_connections,
          (SELECT pg_database_size('contractorlens')) as database_size
      `);

      const stats = result.rows[0];
      
      return {
        activeConnections: stats.active_connections || 0,
        databaseSize: stats.database_size || 0,
        performanceCheck: stats.performance_check || [],
        connectionPool: {
          total: db.totalCount || 0,
          idle: db.idleCount || 0,
          waiting: db.waitingCount || 0
        }
      };
    } catch (error) {
      console.error('Failed to collect database metrics:', error);
      return {
        activeConnections: 0,
        databaseSize: 0,
        performanceCheck: [],
        connectionPool: { total: 0, idle: 0, waiting: 0 },
        error: error.message
      };
    }
  }

  calculatePerformanceMetrics() {
    const metrics = this.metricsHistory.slice(-10); // Last 10 measurements
    
    if (metrics.length === 0) {
      return {
        trend: 'stable',
        averageResponseTime: 0,
        errorRateTrend: 'stable',
        memoryTrend: 'stable',
        overallHealth: 'unknown'
      };
    }

    // Calculate trends
    const responseTimes = metrics.map(m => m.application?.requests?.averageResponseTime || 0);
    const errorRates = metrics.map(m => m.application?.requests?.errorRate || 0);
    const memoryUsages = metrics.map(m => m.system?.memory?.usagePercentage || 0);

    return {
      trend: this.calculateTrend(responseTimes),
      averageResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
      errorRateTrend: this.calculateTrend(errorRates),
      memoryTrend: this.calculateTrend(memoryUsages),
      overallHealth: this.calculateOverallHealth(metrics[metrics.length - 1])
    };
  }

  // MARK: - Alert System

  checkAlerts(metrics) {
    const alerts = [];

    // Response time alert
    if (metrics.application.requests.averageResponseTime > this.config.alertThresholds.responseTime) {
      alerts.push({
        type: 'high_response_time',
        severity: 'warning',
        message: `Average response time is ${metrics.application.requests.averageResponseTime.toFixed(0)}ms (threshold: ${this.config.alertThresholds.responseTime}ms)`,
        value: metrics.application.requests.averageResponseTime,
        threshold: this.config.alertThresholds.responseTime
      });
    }

    // Error rate alert
    if (metrics.application.requests.errorRate > this.config.alertThresholds.errorRate) {
      alerts.push({
        type: 'high_error_rate',
        severity: 'critical',
        message: `Error rate is ${(metrics.application.requests.errorRate * 100).toFixed(2)}% (threshold: ${this.config.alertThresholds.errorRate * 100}%)`,
        value: metrics.application.requests.errorRate,
        threshold: this.config.alertThresholds.errorRate
      });
    }

    // Memory usage alert
    if (metrics.system.memory.usagePercentage > this.config.alertThresholds.memoryUsage * 100) {
      alerts.push({
        type: 'high_memory_usage',
        severity: 'warning',
        message: `Memory usage is ${metrics.system.memory.usagePercentage.toFixed(1)}% (threshold: ${this.config.alertThresholds.memoryUsage * 100}%)`,
        value: metrics.system.memory.usagePercentage,
        threshold: this.config.alertThresholds.memoryUsage * 100
      });
    }

    // CPU usage alert
    if (metrics.system.cpu.usage > this.config.alertThresholds.cpuUsage * 100) {
      alerts.push({
        type: 'high_cpu_usage',
        severity: 'warning',
        message: `CPU usage is ${metrics.system.cpu.usage.toFixed(1)}% (threshold: ${this.config.alertThresholds.cpuUsage * 100}%)`,
        value: metrics.system.cpu.usage,
        threshold: this.config.alertThresholds.cpuUsage * 100
      });
    }

    // Database connection alert
    if (metrics.database.activeConnections > this.config.alertThresholds.concurrentConnections) {
      alerts.push({
        type: 'high_db_connections',
        severity: 'critical',
        message: `Database connections: ${metrics.database.activeConnections} (threshold: ${this.config.alertThresholds.concurrentConnections})`,
        value: metrics.database.activeConnections,
        threshold: this.config.alertThresholds.concurrentConnections
      });
    }

    // Process new alerts
    for (const alert of alerts) {
      this.processAlert(alert);
    }

    // Clear resolved alerts
    this.clearResolvedAlerts(metrics);
  }

  processAlert(alert) {
    const alertKey = `${alert.type}_${alert.threshold}`;
    
    if (!this.activeAlerts.has(alertKey)) {
      // New alert
      const alertRecord = {
        ...alert,
        id: this.generateAlertId(),
        timestamp: Date.now(),
        count: 1,
        firstOccurrence: Date.now(),
        lastOccurrence: Date.now()
      };

      this.activeAlerts.set(alertKey, alertRecord);
      this.alertHistory.push(alertRecord);
      
      console.log(`🚨 ALERT [${alert.severity.toUpperCase()}]: ${alert.message}`);
      this.emit('alert_triggered', alertRecord);
      
      // Send to external alerting systems
      this.sendExternalAlert(alertRecord);
      
    } else {
      // Update existing alert
      const existingAlert = this.activeAlerts.get(alertKey);
      existingAlert.count++;
      existingAlert.lastOccurrence = Date.now();
      existingAlert.value = alert.value;
    }
  }

  clearResolvedAlerts(metrics) {
    const keysToRemove = [];
    
    for (const [alertKey, alert] of this.activeAlerts.entries()) {
      let isResolved = false;
      
      // Check if alert condition is resolved
      switch (alert.type) {
        case 'high_response_time':
          isResolved = metrics.application.requests.averageResponseTime <= alert.threshold * 0.9;
          break;
        case 'high_error_rate':
          isResolved = metrics.application.requests.errorRate <= alert.threshold * 0.9;
          break;
        case 'high_memory_usage':
          isResolved = metrics.system.memory.usagePercentage <= alert.threshold * 0.9;
          break;
        case 'high_cpu_usage':
          isResolved = metrics.system.cpu.usage <= alert.threshold * 0.9;
          break;
        case 'high_db_connections':
          isResolved = metrics.database.activeConnections <= alert.threshold * 0.9;
          break;
      }
      
      if (isResolved) {
        keysToRemove.push(alertKey);
        console.log(`✅ RESOLVED: ${alert.message}`);
        this.emit('alert_resolved', alert);
      }
    }
    
    keysToRemove.forEach(key => this.activeAlerts.delete(key));
  }

  // MARK: - Request Tracking

  setupRequestTracking() {
    // This would be integrated with the Express app
    // For now, providing interface for middleware integration
  }

  trackRequest(req, res, responseTime, statusCode) {
    this.requestMetrics.total++;
    this.requestMetrics.totalResponseTime += responseTime;
    this.requestMetrics.averageResponseTime = this.requestMetrics.totalResponseTime / this.requestMetrics.total;
    
    if (statusCode >= 200 && statusCode < 400) {
      this.requestMetrics.successful++;
    } else {
      this.requestMetrics.failed++;
    }
    
    // Emit request event for real-time monitoring
    this.emit('request_tracked', {
      path: req.path,
      method: req.method,
      statusCode,
      responseTime,
      timestamp: Date.now()
    });
  }

  // MARK: - System Monitoring Helpers

  async getCPUUsage() {
    return new Promise((resolve) => {
      const startUsage = process.cpuUsage();
      
      setTimeout(() => {
        const endUsage = process.cpuUsage(startUsage);
        const totalUsage = endUsage.user + endUsage.system;
        const percentage = (totalUsage / 1000000) * 100; // Convert to percentage
        resolve(Math.min(percentage, 100));
      }, 100);
    });
  }

  async getActiveConnections() {
    // In production, this would query actual network connections
    // For now, return estimate based on request metrics
    return Math.min(this.requestMetrics.total * 0.1, 100);
  }

  getCacheMetrics() {
    // This would integrate with the caching system
    return {
      hits: 0,
      misses: 0,
      hitRate: 0,
      size: 0
    };
  }

  getQueueMetrics() {
    // This would integrate with any queue systems
    return {
      length: 0,
      processing: 0,
      failed: 0
    };
  }

  // MARK: - Trend Analysis

  calculateTrend(values) {
    if (values.length < 2) return 'stable';
    
    const first = values.slice(0, Math.floor(values.length / 2));
    const second = values.slice(Math.floor(values.length / 2));
    
    const firstAvg = first.reduce((a, b) => a + b, 0) / first.length;
    const secondAvg = second.reduce((a, b) => a + b, 0) / second.length;
    
    const difference = secondAvg - firstAvg;
    const threshold = firstAvg * 0.1; // 10% change threshold
    
    if (Math.abs(difference) < threshold) return 'stable';
    return difference > 0 ? 'increasing' : 'decreasing';
  }

  calculateOverallHealth(metrics) {
    if (!metrics) return 'unknown';
    
    let healthScore = 100;
    
    // Deduct points for various issues
    if (metrics.application.requests.errorRate > 0.01) healthScore -= 20;
    if (metrics.application.requests.averageResponseTime > 2000) healthScore -= 15;
    if (metrics.system.memory.usagePercentage > 80) healthScore -= 10;
    if (metrics.system.cpu.usage > 70) healthScore -= 10;
    if (metrics.database.activeConnections > 50) healthScore -= 10;
    
    if (healthScore >= 90) return 'excellent';
    if (healthScore >= 75) return 'good';
    if (healthScore >= 60) return 'fair';
    return 'poor';
  }

  // MARK: - Data Management

  storeMetrics(metrics) {
    this.metricsHistory.push(metrics);
    
    // Clean old metrics
    const cutoffTime = Date.now() - this.config.retention.metrics;
    this.metricsHistory = this.metricsHistory.filter(m => m.timestamp > cutoffTime);
  }

  // MARK: - External Integration

  sendExternalAlert(alert) {
    // Integration points for external alerting systems
    // Slack, PagerDuty, email, etc.
    
    console.log(`📡 Sending external alert: ${alert.type}`);
    this.emit('external_alert', alert);
  }

  // MARK: - Reporting

  generatePerformanceReport(timeRange = 24 * 60 * 60 * 1000) { // 24 hours default
    const cutoffTime = Date.now() - timeRange;
    const relevantMetrics = this.metricsHistory.filter(m => m.timestamp > cutoffTime);
    
    if (relevantMetrics.length === 0) {
      return { error: 'No metrics available for the specified time range' };
    }

    const report = {
      generatedAt: new Date().toISOString(),
      timeRange: `${timeRange / (60 * 60 * 1000)} hours`,
      summary: this.calculateReportSummary(relevantMetrics),
      performance: this.calculatePerformanceStats(relevantMetrics),
      alerts: this.getRecentAlerts(cutoffTime),
      recommendations: this.generateRecommendations(relevantMetrics)
    };

    return report;
  }

  calculateReportSummary(metrics) {
    const latest = metrics[metrics.length - 1];
    
    return {
      totalRequests: latest.application.requests.total,
      averageResponseTime: latest.application.requests.averageResponseTime,
      errorRate: latest.application.requests.errorRate,
      uptime: latest.system.uptime,
      overallHealth: latest.performance.overallHealth
    };
  }

  calculatePerformanceStats(metrics) {
    const responseTimes = metrics.map(m => m.application.requests.averageResponseTime);
    const errorRates = metrics.map(m => m.application.requests.errorRate);
    
    return {
      averageResponseTime: responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length,
      maxResponseTime: Math.max(...responseTimes),
      minResponseTime: Math.min(...responseTimes),
      averageErrorRate: errorRates.reduce((a, b) => a + b, 0) / errorRates.length,
      maxErrorRate: Math.max(...errorRates)
    };
  }

  getRecentAlerts(cutoffTime) {
    return this.alertHistory
      .filter(alert => alert.timestamp > cutoffTime)
      .sort((a, b) => b.timestamp - a.timestamp);
  }

  generateRecommendations(metrics) {
    const recommendations = [];
    const latest = metrics[metrics.length - 1];
    
    if (latest.application.requests.averageResponseTime > 1500) {
      recommendations.push('Consider API response time optimization');
    }
    
    if (latest.application.requests.errorRate > 0.02) {
      recommendations.push('Investigate and address high error rate');
    }
    
    if (latest.system.memory.usagePercentage > 75) {
      recommendations.push('Monitor memory usage and consider scaling');
    }
    
    if (latest.database.activeConnections > 30) {
      recommendations.push('Review database connection pooling settings');
    }
    
    return recommendations;
  }

  // MARK: - Utility Methods

  generateAlertId() {
    return `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  resetRequestMetrics() {
    this.requestMetrics = {
      total: 0,
      successful: 0,
      failed: 0,
      averageResponseTime: 0,
      totalResponseTime: 0,
      lastResetTime: Date.now()
    };
  }

  // MARK: - API Methods

  getCurrentMetrics() {
    return this.metricsHistory[this.metricsHistory.length - 1] || null;
  }

  getActiveAlerts() {
    return Array.from(this.activeAlerts.values());
  }

  getHealthStatus() {
    const currentMetrics = this.getCurrentMetrics();
    
    return {
      status: currentMetrics?.performance?.overallHealth || 'unknown',
      uptime: currentMetrics?.system?.uptime || 0,
      activeAlerts: this.activeAlerts.size,
      lastUpdated: currentMetrics?.timestamp || null
    };
  }
}

// Express middleware for request tracking
function createMonitoringMiddleware(monitor) {
  return (req, res, next) => {
    const startTime = performance.now();
    
    res.on('finish', () => {
      const responseTime = performance.now() - startTime;
      monitor.trackRequest(req, res, responseTime, res.statusCode);
    });
    
    next();
  };
}

// Export for use in production
module.exports = {
  ProductionMonitor,
  createMonitoringMiddleware
};