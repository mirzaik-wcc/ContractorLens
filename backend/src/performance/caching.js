/**
 * ContractorLens API Performance Caching Layer
 * Performance Engineer: PERF001 - Phase 2 API Optimization
 * Target: <2s API response time for estimate generation
 * Created: 2025-09-05
 */

const NodeCache = require('node-cache');

/**
 * Multi-tier caching strategy for ContractorLens Assembly Engine
 * 
 * Cache Hierarchy:
 * 1. Memory Cache (fastest, TTL-based)
 * 2. Location Modifiers (rarely change, long TTL)
 * 3. Assembly Templates (moderate change, medium TTL)
 * 4. Item Costs (frequent updates, short TTL)
 */
class PerformanceCacheManager {
  constructor() {
    // Location modifiers cache (rarely change)
    this.locationCache = new NodeCache({
      stdTTL: 3600,        // 1 hour TTL
      checkperiod: 600,    // Check expired keys every 10 minutes
      maxKeys: 1000,       // Support 1000 different locations
      useClones: false     // Performance optimization
    });

    // Assembly definitions cache (moderate change frequency)
    this.assemblyCache = new NodeCache({
      stdTTL: 1800,        // 30 minute TTL
      checkperiod: 300,    // Check every 5 minutes
      maxKeys: 500,        // Support 500 different assemblies
      useClones: false
    });

    // Item costs cache (more dynamic, shorter TTL)
    this.itemCostCache = new NodeCache({
      stdTTL: 900,         // 15 minute TTL
      checkperiod: 120,    // Check every 2 minutes
      maxKeys: 2000,       // Support 2000 different items
      useClones: false
    });

    // Retail price cache (very dynamic, shortest TTL)
    this.retailPriceCache = new NodeCache({
      stdTTL: 300,         // 5 minute TTL
      checkperiod: 60,     // Check every minute
      maxKeys: 5000,       // Support many item+location combinations
      useClones: false
    });

    // Complete estimate cache (for identical requests)
    this.estimateCache = new NodeCache({
      stdTTL: 600,         // 10 minute TTL for complete estimates
      checkperiod: 120,    // Check every 2 minutes
      maxKeys: 100,        // Cache 100 recent complete estimates
      useClones: true      // Need clones for estimate objects
    });

    // Performance metrics tracking
    this.metrics = {
      hits: 0,
      misses: 0,
      locationHits: 0,
      assemblyHits: 0,
      itemCostHits: 0,
      retailPriceHits: 0,
      estimateHits: 0,
      totalRequests: 0
    };

    // Setup cache event listeners for monitoring
    this.setupCacheMonitoring();
  }

  setupCacheMonitoring() {
    const caches = [
      { name: 'location', cache: this.locationCache },
      { name: 'assembly', cache: this.assemblyCache },
      { name: 'itemCost', cache: this.itemCostCache },
      { name: 'retailPrice', cache: this.retailPriceCache },
      { name: 'estimate', cache: this.estimateCache }
    ];

    caches.forEach(({ name, cache }) => {
      cache.on('expired', (key, value) => {
        console.log(`Cache expired: ${name} key ${key}`);
      });

      cache.on('flush', () => {
        console.log(`Cache flushed: ${name}`);
      });
    });
  }

  /**
   * Location modifier caching with ZIP code prefix optimization
   */
  async getLocationModifiers(zipCode, fallbackFunction) {
    const cacheKey = `location_${zipCode}`;
    this.metrics.totalRequests++;

    // Try exact match first
    let locationData = this.locationCache.get(cacheKey);
    if (locationData) {
      this.metrics.hits++;
      this.metrics.locationHits++;
      return locationData;
    }

    // Try ZIP prefix cache (for range matches)
    const zipPrefix = zipCode.substring(0, 3);
    const prefixKey = `location_prefix_${zipPrefix}`;
    locationData = this.locationCache.get(prefixKey);
    if (locationData) {
      this.metrics.hits++;
      this.metrics.locationHits++;
      // Cache the specific ZIP for faster future lookups
      this.locationCache.set(cacheKey, locationData);
      return locationData;
    }

    // Cache miss - fetch from database
    this.metrics.misses++;
    locationData = await fallbackFunction(zipCode);
    
    if (locationData) {
      // Cache both specific ZIP and prefix for range matching
      this.locationCache.set(cacheKey, locationData);
      if (locationData.metro_name !== 'National Average') {
        this.locationCache.set(prefixKey, locationData);
      }
    }

    return locationData;
  }

  /**
   * Assembly items caching with quality tier optimization
   */
  async getAssemblyItems(assemblyId, qualityTier, fallbackFunction) {
    const cacheKey = `assembly_${assemblyId}_${qualityTier}`;
    this.metrics.totalRequests++;

    let assemblyItems = this.assemblyCache.get(cacheKey);
    if (assemblyItems) {
      this.metrics.hits++;
      this.metrics.assemblyHits++;
      return assemblyItems;
    }

    // Cache miss
    this.metrics.misses++;
    assemblyItems = await fallbackFunction(assemblyId);
    
    if (assemblyItems && assemblyItems.length > 0) {
      // Filter by quality tier and cache
      const filteredItems = assemblyItems.filter(item => 
        !item.quality_tier || item.quality_tier === qualityTier
      );
      this.assemblyCache.set(cacheKey, filteredItems);
      return filteredItems;
    }

    return assemblyItems;
  }

  /**
   * Item cost caching with location-aware pricing
   */
  async getItemCost(itemId, locationId, itemType, fallbackFunction) {
    const cacheKey = `cost_${itemId}_${locationId}`;
    this.metrics.totalRequests++;

    let itemCost = this.itemCostCache.get(cacheKey);
    if (itemCost !== undefined) {
      this.metrics.hits++;
      this.metrics.itemCostHits++;
      return itemCost;
    }

    // Cache miss
    this.metrics.misses++;
    itemCost = await fallbackFunction(itemId, locationId, itemType);
    
    if (itemCost !== null && itemCost !== undefined) {
      this.itemCostCache.set(cacheKey, itemCost);
    }

    return itemCost;
  }

  /**
   * Retail price caching with freshness validation
   */
  async getRetailPrice(itemId, locationId, fallbackFunction) {
    const cacheKey = `retail_${itemId}_${locationId}`;
    this.metrics.totalRequests++;

    let retailPrice = this.retailPriceCache.get(cacheKey);
    if (retailPrice !== undefined) {
      this.metrics.hits++;
      this.metrics.retailPriceHits++;
      return retailPrice;
    }

    // Cache miss
    this.metrics.misses++;
    retailPrice = await fallbackFunction(itemId, locationId);
    
    // Cache the result (even if null, to avoid repeated DB queries)
    this.retailPriceCache.set(cacheKey, retailPrice);
    return retailPrice;
  }

  /**
   * Complete estimate caching for identical requests
   */
  generateEstimateKey(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    // Create hash key for estimate caching
    const estimateHash = require('crypto')
      .createHash('md5')
      .update(JSON.stringify({
        takeoffData: this.normalizeNumberPrecision(takeoffData),
        jobType,
        finishLevel,
        zipCode: zipCode.substring(0, 5), // Use 5-digit ZIP for caching
        userSettings: {
          hourly_rate: userSettings.hourly_rate,
          markup_percentage: userSettings.markup_percentage,
          tax_rate: userSettings.tax_rate
        }
      }))
      .digest('hex');
    
    return `estimate_${estimateHash}`;
  }

  /**
   * Normalize numbers to prevent cache misses due to floating point precision
   */
  normalizeNumberPrecision(obj) {
    if (typeof obj === 'number') {
      return Math.round(obj * 100) / 100; // Round to 2 decimal places
    } else if (Array.isArray(obj)) {
      return obj.map(item => this.normalizeNumberPrecision(item));
    } else if (obj && typeof obj === 'object') {
      const normalized = {};
      for (const [key, value] of Object.entries(obj)) {
        normalized[key] = this.normalizeNumberPrecision(value);
      }
      return normalized;
    }
    return obj;
  }

  async getCachedEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    const cacheKey = this.generateEstimateKey(takeoffData, jobType, finishLevel, zipCode, userSettings);
    this.metrics.totalRequests++;

    const cachedEstimate = this.estimateCache.get(cacheKey);
    if (cachedEstimate) {
      this.metrics.hits++;
      this.metrics.estimateHits++;
      
      // Add cache metadata
      cachedEstimate.metadata = {
        ...cachedEstimate.metadata,
        cachedResult: true,
        cacheTimestamp: new Date().toISOString()
      };
      
      return cachedEstimate;
    }

    this.metrics.misses++;
    return null;
  }

  setCachedEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings, estimate) {
    const cacheKey = this.generateEstimateKey(takeoffData, jobType, finishLevel, zipCode, userSettings);
    
    // Add cache metadata to estimate
    estimate.metadata = {
      ...estimate.metadata,
      cachedResult: false,
      cacheKey: cacheKey.substring(0, 16) // Truncate for logging
    };

    this.estimateCache.set(cacheKey, estimate);
  }

  /**
   * Batch cache warming for common requests
   */
  async warmCache(commonZipCodes, commonAssemblies, dbConnection) {
    console.log('Starting cache warming process...');
    
    try {
      // Warm location modifiers cache
      const locationPromises = commonZipCodes.map(async (zipCode) => {
        try {
          const result = await dbConnection.query(`
            SELECT location_id, metro_name, state_code, material_modifier, labor_modifier
            FROM contractorlens.LocationCostModifiers
            WHERE zip_code_range LIKE $1 OR zip_code_range = $2
            LIMIT 1
          `, [`${zipCode.substring(0, 3)}%`, zipCode]);
          
          if (result.rows.length > 0) {
            this.locationCache.set(`location_${zipCode}`, result.rows[0]);
          }
        } catch (error) {
          console.warn(`Failed to warm cache for ZIP ${zipCode}:`, error.message);
        }
      });

      // Warm assembly items cache
      const assemblyPromises = commonAssemblies.map(async (assemblyId) => {
        try {
          const result = await dbConnection.query(`
            SELECT ai.quantity, i.* FROM contractorlens.AssemblyItems ai
            JOIN contractorlens.Items i ON ai.item_id = i.item_id
            WHERE ai.assembly_id = $1
          `, [assemblyId]);
          
          if (result.rows.length > 0) {
            this.assemblyCache.set(`assembly_${assemblyId}_good`, result.rows);
            this.assemblyCache.set(`assembly_${assemblyId}_better`, result.rows);
            this.assemblyCache.set(`assembly_${assemblyId}_best`, result.rows);
          }
        } catch (error) {
          console.warn(`Failed to warm cache for assembly ${assemblyId}:`, error.message);
        }
      });

      await Promise.allSettled([...locationPromises, ...assemblyPromises]);
      console.log('Cache warming completed');
      
    } catch (error) {
      console.error('Cache warming failed:', error);
    }
  }

  /**
   * Cache performance monitoring and optimization
   */
  getCacheStats() {
    const hitRate = this.metrics.totalRequests > 0 
      ? (this.metrics.hits / this.metrics.totalRequests * 100).toFixed(2) 
      : 0;

    return {
      performance: {
        totalRequests: this.metrics.totalRequests,
        cacheHits: this.metrics.hits,
        cacheMisses: this.metrics.misses,
        hitRate: `${hitRate}%`,
        targetHitRate: '80%+'
      },
      cacheBreakdown: {
        locationHits: this.metrics.locationHits,
        assemblyHits: this.metrics.assemblyHits,
        itemCostHits: this.metrics.itemCostHits,
        retailPriceHits: this.metrics.retailPriceHits,
        estimateHits: this.metrics.estimateHits
      },
      memoryUsage: {
        locationCache: {
          keys: this.locationCache.keys().length,
          stats: this.locationCache.getStats()
        },
        assemblyCache: {
          keys: this.assemblyCache.keys().length,
          stats: this.assemblyCache.getStats()
        },
        itemCostCache: {
          keys: this.itemCostCache.keys().length,
          stats: this.itemCostCache.getStats()
        },
        retailPriceCache: {
          keys: this.retailPriceCache.keys().length,
          stats: this.retailPriceCache.getStats()
        },
        estimateCache: {
          keys: this.estimateCache.keys().length,
          stats: this.estimateCache.getStats()
        }
      },
      recommendations: this.generateOptimizationRecommendations(hitRate)
    };
  }

  generateOptimizationRecommendations(hitRate) {
    const recommendations = [];
    
    if (parseFloat(hitRate) < 70) {
      recommendations.push('Cache hit rate below 70% - consider increasing TTL values');
    }
    
    if (this.locationCache.keys().length > 800) {
      recommendations.push('Location cache approaching capacity - consider cleanup');
    }
    
    if (this.metrics.estimateHits === 0 && this.metrics.totalRequests > 50) {
      recommendations.push('No estimate cache hits - verify request normalization');
    }
    
    if (recommendations.length === 0) {
      recommendations.push('Cache performance is optimal');
    }
    
    return recommendations;
  }

  /**
   * Cache cleanup and maintenance
   */
  performMaintenance() {
    console.log('Performing cache maintenance...');
    
    // Force cleanup of expired keys
    [
      this.locationCache,
      this.assemblyCache,
      this.itemCostCache,
      this.retailPriceCache,
      this.estimateCache
    ].forEach(cache => {
      const keysBefore = cache.keys().length;
      cache.flushExpired();
      const keysAfter = cache.keys().length;
      
      if (keysBefore !== keysAfter) {
        console.log(`Cleaned ${keysBefore - keysAfter} expired keys`);
      }
    });

    // Reset metrics for next period
    const oldMetrics = { ...this.metrics };
    this.metrics = {
      hits: 0,
      misses: 0,
      locationHits: 0,
      assemblyHits: 0,
      itemCostHits: 0,
      retailPriceHits: 0,
      estimateHits: 0,
      totalRequests: 0
    };

    console.log('Cache maintenance completed');
    return oldMetrics;
  }

  /**
   * Clear all caches (for testing or critical updates)
   */
  clearAll() {
    this.locationCache.flushAll();
    this.assemblyCache.flushAll();
    this.itemCostCache.flushAll();
    this.retailPriceCache.flushAll();
    this.estimateCache.flushAll();
    
    console.log('All caches cleared');
  }
}

// Singleton instance for application-wide use
const cacheManager = new PerformanceCacheManager();

module.exports = {
  PerformanceCacheManager,
  cacheManager
};