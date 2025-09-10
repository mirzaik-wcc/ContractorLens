/**
 * Optimized Assembly Engine - Performance Enhanced Version
 * Performance Engineer: PERF001 - Phase 2 API Optimization
 * Target: <2s API response time with caching and query optimization
 * Created: 2025-09-05
 */

const db = require('../config/database');
const { cacheManager } = require('./caching');

/**
 * Performance-optimized Assembly Engine with:
 * - Multi-tier caching strategy
 * - Batch query optimization
 * - Parallel processing
 * - Connection pool management
 */
class OptimizedAssemblyEngine {
  constructor() {
    this.defaultMarkupPercentage = parseFloat(process.env.DEFAULT_MARKUP_PERCENTAGE) || 25;
    this.defaultTaxRate = parseFloat(process.env.DEFAULT_TAX_RATE) || 0.08;
    this.retailPriceFreshnessDays = parseInt(process.env.RETAIL_PRICE_FRESHNESS_DAYS) || 7;
    
    // Performance monitoring
    this.performanceMetrics = {
      estimateCount: 0,
      averageProcessingTime: 0,
      totalProcessingTime: 0,
      cacheHitRate: 0
    };
  }

  /**
   * Main estimate calculation method - Performance Optimized
   * Uses caching, parallel processing, and batch queries
   */
  async calculateEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    const startTime = Date.now();
    
    try {
      console.log(`🚀 Starting optimized estimate calculation for ${jobType} job, finish level: ${finishLevel}`);
      
      // Step 1: Check for cached complete estimate
      const cachedEstimate = await cacheManager.getCachedEstimate(
        takeoffData, jobType, finishLevel, zipCode, userSettings
      );
      
      if (cachedEstimate) {
        console.log(`⚡ Cache hit: Returning cached estimate in ${Date.now() - startTime}ms`);
        this.updatePerformanceMetrics(Date.now() - startTime, true);
        return cachedEstimate;
      }

      // Step 2: Validate inputs (fast fail)
      this.validateInputs(takeoffData, jobType, finishLevel, zipCode, userSettings);
      
      // Step 3: Parallel data fetching for independent operations
      const [locationData, assemblies] = await Promise.all([
        this.getLocationDataOptimized(zipCode),
        this.getAssembliesForJobTypeOptimized(jobType)
      ]);

      if (assemblies.length === 0) {
        throw new Error(`No assemblies found for job type: ${jobType}`);
      }

      // Step 4: Batch process all assemblies with parallel item fetching
      const lineItemsPromises = assemblies.map(assembly => 
        this.processAssemblyOptimized(assembly, takeoffData, finishLevel, locationData, userSettings)
      );

      const allLineItemArrays = await Promise.all(lineItemsPromises);
      const lineItems = allLineItemArrays.flat().filter(item => item !== null);

      // Step 5: Add finish-level specific items in parallel
      const finishItemsPromise = this.selectFinishItemsOptimized(
        finishLevel, takeoffData, locationData, userSettings
      );

      const finishItems = await finishItemsPromise;
      lineItems.push(...finishItems);

      // Step 6: Calculate totals and apply markup/tax
      const subtotal = lineItems.reduce((sum, item) => sum + item.totalCost, 0);
      const finalEstimate = this.applyMarkupAndTax(lineItems, subtotal, userSettings);

      // Step 7: Add metadata and cache the result
      finalEstimate.metadata = {
        totalLaborHours: this.calculateTotalLaborHours(lineItems),
        finishLevel,
        location: locationData,
        calculationDate: new Date().toISOString(),
        engineVersion: '2.0-optimized',
        processingTimeMs: Date.now() - startTime,
        cacheUtilization: cacheManager.getCacheStats().performance
      };

      // Cache the complete estimate for future identical requests
      cacheManager.setCachedEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings, finalEstimate);

      const processingTime = Date.now() - startTime;
      console.log(`✅ Optimized estimate completed: $${finalEstimate.grandTotal.toFixed(2)} in ${processingTime}ms`);
      
      this.updatePerformanceMetrics(processingTime, false);
      return finalEstimate;
      
    } catch (error) {
      console.error('❌ Optimized Assembly Engine calculation error:', error);
      this.updatePerformanceMetrics(Date.now() - startTime, false);
      throw new Error(`Estimate calculation failed: ${error.message}`);
    }
  }

  /**
   * Performance-optimized location data retrieval with caching
   */
  async getLocationDataOptimized(zipCode) {
    return await cacheManager.getLocationModifiers(zipCode, async (zip) => {
      const shortZip = zip.substring(0, 5);
      
      // Use the optimized function from database performance layer
      const result = await db.query(`
        SELECT * FROM contractorlens.get_location_modifiers_optimized($1)
      `, [shortZip]);
      
      if (result.rows.length === 0) {
        console.warn(`⚠️  No location data found for ZIP code ${zipCode}, using national averages`);
        return {
          location_id: null,
          metro_name: 'National Average',
          state_code: 'US',
          material_modifier: 1.000,
          labor_modifier: 1.000
        };
      }
      
      return result.rows[0];
    });
  }

  /**
   * Performance-optimized assembly retrieval with quality tier filtering
   */
  async getAssembliesForJobTypeOptimized(jobType) {
    const cacheKey = `assemblies_${jobType}`;
    
    let assemblies = cacheManager.assemblyCache.get(cacheKey);
    if (assemblies) {
      return assemblies;
    }

    // Use enhanced index for faster category lookup
    const result = await db.query(`
      SELECT assembly_id, name, description, category, base_unit
      FROM contractorlens.Assemblies
      WHERE category = $1
      ORDER BY name
    `, [jobType]);
    
    if (result.rows.length > 0) {
      cacheManager.assemblyCache.set(cacheKey, result.rows);
    }
    
    return result.rows;
  }

  /**
   * Optimized assembly processing with batched item fetching
   */
  async processAssemblyOptimized(assembly, takeoffData, finishLevel, locationData, userSettings) {
    // Calculate quantity for this assembly
    const takeoffQuantity = this.matchTakeoffToAssembly(takeoffData, assembly);
    if (!takeoffQuantity || takeoffQuantity <= 0) {
      return [];
    }

    console.log(`🔧 Processing ${assembly.name}: ${takeoffQuantity} ${assembly.base_unit}`);

    // Get assembly items with caching and materialized view optimization
    const assemblyItems = await cacheManager.getAssemblyItems(
      assembly.assembly_id,
      finishLevel,
      async (assemblyId) => {
        // Use materialized view for faster joins
        const result = await db.query(`
          SELECT assembly_quantity as quantity, item_id, csi_code, description, unit, category,
                 quantity_per_unit, quality_tier, national_average_cost, item_type
          FROM contractorlens.assembly_items_materialized
          WHERE assembly_id = $1
          ORDER BY item_type, csi_code
        `, [assemblyId]);
        
        return result.rows;
      }
    );

    if (assemblyItems.length === 0) {
      console.warn(`⚠️  No items found for assembly: ${assembly.name}`);
      return [];
    }

    // Process all component items in parallel with batched cost lookups
    const componentPromises = assemblyItems.map(component => 
      this.calculateComponentCostOptimized(
        component, takeoffQuantity, finishLevel, locationData, userSettings
      )
    );

    const allComponents = await Promise.all(componentPromises);
    return allComponents.flat();
  }

  /**
   * Optimized component cost calculation with caching
   */
  async calculateComponentCostOptimized(component, assemblyQuantity, finishLevel, locationData, userSettings) {
    // Filter by quality tier if specified
    if (component.quality_tier && component.quality_tier !== finishLevel) {
      return [];
    }

    const totalQuantity = assemblyQuantity * component.quantity;
    const lineItems = [];

    if (component.item_type === 'labor') {
      // Labor calculation (no external lookups needed)
      const laborHours = totalQuantity * (component.quantity_per_unit || 0);
      const hourlyRate = userSettings.hourly_rate || 50;
      const laborCost = laborHours * hourlyRate;
      
      lineItems.push({
        itemId: component.item_id,
        csiCode: component.csi_code,
        description: `${component.description} - Labor`,
        quantity: laborHours,
        unit: 'hours',
        unitCost: hourlyRate,
        totalCost: laborCost,
        type: 'labor',
        category: component.category
      });

    } else {
      // Material/Equipment calculation with optimized cost lookup
      const localizedCost = await this.getLocalizedCostOptimized(component, locationData);
      const materialCost = totalQuantity * localizedCost;
      
      lineItems.push({
        itemId: component.item_id,
        csiCode: component.csi_code,
        description: component.description,
        quantity: totalQuantity,
        unit: component.unit,
        unitCost: localizedCost,
        totalCost: materialCost,
        type: component.item_type,
        category: component.category
      });
    }
    
    return lineItems;
  }

  /**
   * Optimized localized cost calculation with multi-tier caching
   */
  async getLocalizedCostOptimized(item, locationData) {
    // Use cached cost lookup with retail price fallback
    return await cacheManager.getItemCost(
      item.item_id,
      locationData.location_id,
      item.item_type,
      async (itemId, locationId, itemType) => {
        // First, try cached retail price
        const retailPrice = await cacheManager.getRetailPrice(
          itemId,
          locationId,
          async (iId, lId) => {
            if (!lId) return null;
            
            // Use optimized retail price function
            const result = await db.query(`
              SELECT contractorlens.get_fresh_retail_price($1, $2, $3) as retail_price
            `, [iId, lId, this.retailPriceFreshnessDays]);
            
            return result.rows[0]?.retail_price || null;
          }
        );

        if (retailPrice) {
          console.log(`💰 Using cached retail price for ${item.description}: $${retailPrice}`);
          return parseFloat(retailPrice);
        }

        // Fallback to national average with location modifier (cached)
        const nationalCost = parseFloat(item.national_average_cost) || 0;
        
        let modifier = 1.000;
        if (itemType === 'material') {
          modifier = parseFloat(locationData.material_modifier) || 1.000;
        } else if (itemType === 'labor') {
          modifier = parseFloat(locationData.labor_modifier) || 1.000;
        }

        const localizedCost = nationalCost * modifier;
        console.log(`📊 Using localized cost for ${item.description}: $${nationalCost} × ${modifier} = $${localizedCost.toFixed(2)}`);
        
        return localizedCost;
      }
    );
  }

  /**
   * Optimized finish item selection with batch processing
   */
  async selectFinishItemsOptimized(finishLevel, takeoffData, locationData, userSettings) {
    const finishItems = [];
    
    // Use optimized function for finish items
    const result = await db.query(`
      SELECT * FROM contractorlens.get_finish_items_optimized($1, $2)
    `, [finishLevel, ['fixtures', 'finishes', 'appliances']]);

    // Process finish items in parallel
    const finishItemPromises = result.rows.map(async (item) => {
      const quantity = this.determineFinishItemQuantity(item, takeoffData);
      if (quantity > 0) {
        const localizedCost = await this.getLocalizedCostOptimized(item, locationData);
        const totalCost = quantity * localizedCost;
        
        return {
          itemId: item.item_id,
          csiCode: item.csi_code,
          description: `${item.description} (${finishLevel} level)`,
          quantity: quantity,
          unit: item.unit,
          unitCost: localizedCost,
          totalCost: totalCost,
          type: item.item_type,
          category: item.category
        };
      }
      return null;
    });

    const resolvedFinishItems = await Promise.all(finishItemPromises);
    return resolvedFinishItems.filter(item => item !== null);
  }

  /**
   * Performance monitoring and metrics
   */
  updatePerformanceMetrics(processingTime, wasCache) {
    this.performanceMetrics.estimateCount++;
    this.performanceMetrics.totalProcessingTime += processingTime;
    this.performanceMetrics.averageProcessingTime = 
      this.performanceMetrics.totalProcessingTime / this.performanceMetrics.estimateCount;
    
    if (wasCache) {
      this.performanceMetrics.cacheHitRate = 
        ((this.performanceMetrics.cacheHitRate * (this.performanceMetrics.estimateCount - 1)) + 1) / 
        this.performanceMetrics.estimateCount;
    }
  }

  getPerformanceStats() {
    return {
      engineMetrics: this.performanceMetrics,
      cacheStats: cacheManager.getCacheStats(),
      performance_targets: {
        api_response_time_ms: 2000,
        cache_hit_rate: '80%+',
        database_query_time_ms: 50
      }
    };
  }

  // Reuse existing utility methods from original AssemblyEngine
  validateInputs(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    if (!takeoffData || typeof takeoffData !== 'object') {
      throw new Error('Invalid takeoff data: must be an object');
    }
    
    if (!jobType || typeof jobType !== 'string') {
      throw new Error('Invalid job type: must be a string');
    }
    
    const validFinishLevels = ['good', 'better', 'best'];
    if (!validFinishLevels.includes(finishLevel)) {
      throw new Error(`Invalid finish level: must be one of ${validFinishLevels.join(', ')}`);
    }
    
    if (!zipCode || !/^\d{5}(-\d{4})?$/.test(zipCode)) {
      throw new Error('Invalid ZIP code: must be 5 or 9 digits');
    }
    
    if (!userSettings || typeof userSettings !== 'object') {
      throw new Error('Invalid user settings: must be an object');
    }
  }

  matchTakeoffToAssembly(takeoffData, assembly) {
    switch (assembly.category) {
      case 'kitchen':
        return takeoffData.kitchens?.[0]?.area || 0;
      case 'bathroom':
        return takeoffData.bathrooms?.[0]?.area || 0;
      case 'room':
      case 'wall':
        if (takeoffData.walls && Array.isArray(takeoffData.walls)) {
          return takeoffData.walls.reduce((sum, wall) => sum + (wall.area || 0), 0);
        }
        return 0;
      case 'flooring':
        if (takeoffData.floors && Array.isArray(takeoffData.floors)) {
          return takeoffData.floors.reduce((sum, floor) => sum + (floor.area || 0), 0);
        }
        return 0;
      case 'ceiling':
        if (takeoffData.ceilings && Array.isArray(takeoffData.ceilings)) {
          return takeoffData.ceilings.reduce((sum, ceiling) => sum + (ceiling.area || 0), 0);
        }
        return 0;
      default:
        console.warn(`Unknown assembly category: ${assembly.category}`);
        return 0;
    }
  }

  determineFinishItemQuantity(item, takeoffData) {
    switch (item.category) {
      case 'fixtures':
        return (takeoffData.bathrooms?.length || 0) + (takeoffData.kitchens?.length || 0);
      case 'appliances':
        return takeoffData.kitchens?.length || 0;
      case 'finishes':
        return this.calculateTotalArea(takeoffData);
      default:
        return 0;
    }
  }

  calculateTotalArea(takeoffData) {
    let totalArea = 0;
    ['walls', 'floors', 'ceilings'].forEach(surface => {
      if (takeoffData[surface] && Array.isArray(takeoffData[surface])) {
        totalArea += takeoffData[surface].reduce((sum, item) => sum + (item.area || 0), 0);
      }
    });
    return totalArea;
  }

  calculateTotalLaborHours(lineItems) {
    return lineItems
      .filter(item => item.type === 'labor')
      .reduce((sum, item) => sum + item.quantity, 0);
  }

  applyMarkupAndTax(lineItems, subtotal, userSettings) {
    const markupPercentage = userSettings.markup_percentage || this.defaultMarkupPercentage;
    const taxRate = userSettings.tax_rate || this.defaultTaxRate;
    
    const materialTotal = lineItems
      .filter(item => item.type === 'material' || item.type === 'equipment')
      .reduce((sum, item) => sum + item.totalCost, 0);
    
    const laborTotal = lineItems
      .filter(item => item.type === 'labor')
      .reduce((sum, item) => sum + item.totalCost, 0);
    
    const markupAmount = subtotal * (markupPercentage / 100);
    const afterMarkup = subtotal + markupAmount;
    
    const taxableAmount = materialTotal + (materialTotal * (markupPercentage / 100));
    const taxAmount = taxableAmount * taxRate;
    
    const grandTotal = afterMarkup + taxAmount;
    
    return {
      lineItems,
      subtotal,
      materialTotal,
      laborTotal,
      markupPercentage,
      markupAmount,
      afterMarkup,
      taxRate,
      taxAmount,
      grandTotal,
      summary: {
        totalLineItems: lineItems.length,
        avgMaterialCostPerSF: materialTotal / Math.max(this.calculateTotalArea({ walls: [{ area: 100 }] }), 1),
        avgLaborCostPerSF: laborTotal / Math.max(this.calculateTotalArea({ walls: [{ area: 100 }] }), 1)
      }
    };
  }
}

module.exports = OptimizedAssemblyEngine;