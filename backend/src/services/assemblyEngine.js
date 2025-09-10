const db = require('../config/database');

/**
 * Assembly Engine - Deterministic Construction Cost Calculator
 * 
 * This is NOT an AI estimator. It performs deterministic calculations using:
 * 1. Structured takeoff data from AR scans
 * 2. Database-driven assembly definitions  
 * 3. Production rates and localized costs
 * 4. User finish level preferences
 * 
 * Cost Hierarchy:
 * 1. Retail prices (if fresh within 7 days)
 * 2. National average × location modifier (fallback)
 */
class AssemblyEngine {
  constructor() {
    this.defaultMarkupPercentage = parseFloat(process.env.DEFAULT_MARKUP_PERCENTAGE) || 25;
    this.defaultTaxRate = parseFloat(process.env.DEFAULT_TAX_RATE) || 0.08;
    this.retailPriceFreshnessDays = parseInt(process.env.RETAIL_PRICE_FRESHNESS_DAYS) || 7;
  }

  /**
   * Main estimate calculation method
   * @param {Object} takeoffData - Structured data from AR scan {walls: [{area: 100, type: 'drywall'}], rooms: [...]}
   * @param {string} jobType - Job category ('kitchen', 'bathroom', 'room', etc.)
   * @param {string} finishLevel - Quality tier ('good', 'better', 'best')
   * @param {string} zipCode - Location for cost localization
   * @param {Object} userSettings - User preferences {hourly_rate: 75, markup_percentage: 25, tax_rate: 0.08}
   * @returns {Object} Complete estimate with line items
   */
  async calculateEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    try {
      console.log(`Starting estimate calculation for ${jobType} job, finish level: ${finishLevel}`);
      
      // Validate inputs
      this.validateInputs(takeoffData, jobType, finishLevel, zipCode, userSettings);
      
      // Get location data for cost modifiers
      const locationData = await this.getLocationData(zipCode);
      
      // Get applicable assemblies for this job type
      const assemblies = await this.getAssembliesForJobType(jobType);
      
      const lineItems = [];
      let totalLaborHours = 0;
      
      // Process each assembly that matches our takeoff data
      for (const assembly of assemblies) {
        console.log(`Processing assembly: ${assembly.name} (${assembly.assembly_id})`);
        
        // Match takeoff data to this assembly
        const takeoffQuantity = this.matchTakeoffToAssembly(takeoffData, assembly);
        if (!takeoffQuantity || takeoffQuantity <= 0) {
          console.log(`No matching takeoff data for assembly: ${assembly.name}`);
          continue;
        }
        
        console.log(`Matched ${takeoffQuantity} ${assembly.base_unit} for ${assembly.name}`);
        
        // Get all items in this assembly
        const assemblyItems = await this.getAssemblyItems(assembly.assembly_id);
        
        // Calculate each component item
        for (const component of assemblyItems) {
          const componentLineItems = await this.calculateComponentCost(
            component,
            takeoffQuantity,
            finishLevel,
            locationData,
            userSettings
          );
          
          lineItems.push(...componentLineItems);
          
          // Track labor hours for project scheduling
          if (component.item_type === 'labor') {
            totalLaborHours += (takeoffQuantity * component.quantity * component.quantity_per_unit);
          }
        }
      }
      
      // Add finish-level specific items that aren't in standard assemblies
      const finishItems = await this.selectFinishItems(
        finishLevel,
        takeoffData,
        locationData,
        userSettings
      );
      lineItems.push(...finishItems);
      
      // Calculate subtotals
      const subtotal = lineItems.reduce((sum, item) => sum + item.totalCost, 0);
      
      // Apply markup and taxes
      const finalEstimate = this.applyMarkupAndTax(lineItems, subtotal, userSettings);
      
      // Add project metadata
      finalEstimate.metadata = {
        totalLaborHours,
        finishLevel,
        location: locationData,
        calculationDate: new Date().toISOString(),
        engineVersion: '1.0'
      };
      
      console.log(`Estimate calculated: $${finalEstimate.grandTotal.toFixed(2)} with ${lineItems.length} line items`);
      return finalEstimate;
      
    } catch (error) {
      console.error('Assembly Engine calculation error:', error);
      throw new Error(`Estimate calculation failed: ${error.message}`);
    }
  }

  /**
   * Validate all required inputs
   */
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

  /**
   * Get location data and cost modifiers for ZIP code
   */
  async getLocationData(zipCode) {
    const shortZip = zipCode.substring(0, 5);
    
    const result = await db.query(`
      SELECT lcm.location_id, lcm.metro_name, lcm.state_code,
             lcm.material_modifier, lcm.labor_modifier
      FROM contractorlens.LocationCostModifiers lcm
      WHERE lcm.zip_code_range = $1 
         OR lcm.zip_code_range LIKE $2
         OR lcm.zip_code_range LIKE $3
      ORDER BY 
        CASE 
          WHEN lcm.zip_code_range = $1 THEN 1
          WHEN lcm.zip_code_range LIKE $2 THEN 2
          ELSE 3
        END
      LIMIT 1
    `, [shortZip, `${shortZip}%`, `${shortZip.substring(0, 3)}%`]);
    
    if (result.rows.length === 0) {
      console.warn(`No location data found for ZIP code ${zipCode}, using national averages`);
      return {
        location_id: null,
        metro_name: 'National Average',
        state_code: 'US',
        material_modifier: 1.000,
        labor_modifier: 1.000
      };
    }
    
    return result.rows[0];
  }

  /**
   * Get assemblies that match the job type
   */
  async getAssembliesForJobType(jobType) {
    const result = await db.query(`
      SELECT assembly_id, name, description, category, base_unit
      FROM contractorlens.Assemblies
      WHERE category = $1
      ORDER BY name
    `, [jobType]);
    
    if (result.rows.length === 0) {
      console.warn(`No assemblies found for job type: ${jobType}`);
    }
    
    return result.rows;
  }

  /**
   * Get all items in an assembly with their quantities
   */
  async getAssemblyItems(assemblyId) {
    const result = await db.query(`
      SELECT 
        ai.quantity,
        i.item_id, i.csi_code, i.description, i.unit, i.category,
        i.quantity_per_unit, i.quality_tier, i.national_average_cost,
        i.item_type
      FROM contractorlens.AssemblyItems ai
      JOIN contractorlens.Items i ON ai.item_id = i.item_id
      WHERE ai.assembly_id = $1
      ORDER BY i.item_type, i.csi_code
    `, [assemblyId]);
    
    return result.rows;
  }

  /**
   * Match takeoff data to assembly requirements
   * This is where AR scan data gets translated to assembly quantities
   */
  matchTakeoffToAssembly(takeoffData, assembly) {
    // For now, implement simple matching logic
    // In production, this would be more sophisticated based on assembly.category
    
    switch (assembly.category) {
      case 'kitchen':
        // Look for kitchen-specific takeoff data
        return takeoffData.kitchens?.[0]?.area || 0;
        
      case 'bathroom':
        // Look for bathroom-specific takeoff data
        return takeoffData.bathrooms?.[0]?.area || 0;
        
      case 'room':
      case 'wall':
        // Sum all wall areas
        if (takeoffData.walls && Array.isArray(takeoffData.walls)) {
          return takeoffData.walls.reduce((sum, wall) => sum + (wall.area || 0), 0);
        }
        return 0;
        
      case 'flooring':
        // Sum all floor areas
        if (takeoffData.floors && Array.isArray(takeoffData.floors)) {
          return takeoffData.floors.reduce((sum, floor) => sum + (floor.area || 0), 0);
        }
        return 0;
        
      case 'ceiling':
        // Sum all ceiling areas
        if (takeoffData.ceilings && Array.isArray(takeoffData.ceilings)) {
          return takeoffData.ceilings.reduce((sum, ceiling) => sum + (ceiling.area || 0), 0);
        }
        return 0;
        
      default:
        console.warn(`Unknown assembly category: ${assembly.category}`);
        return 0;
    }
  }

  /**
   * Calculate cost for a single component item
   */
  async calculateComponentCost(component, assemblyQuantity, finishLevel, locationData, userSettings) {
    const lineItems = [];
    
    // Filter items by finish level if specified
    if (component.quality_tier && component.quality_tier !== finishLevel) {
      console.log(`Skipping ${component.description} - quality tier ${component.quality_tier} doesn't match ${finishLevel}`);
      return lineItems;
    }
    
    // Calculate total quantity needed (assembly quantity × item quantity per assembly)
    const totalQuantity = assemblyQuantity * component.quantity;
    
    if (component.item_type === 'labor') {
      // Labor calculation using production rates
      const laborHours = totalQuantity * (component.quantity_per_unit || 0);
      const hourlyRate = userSettings.hourly_rate || 50; // Default fallback
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
      // Material/Equipment calculation with localized pricing
      const localizedCost = await this.getLocalizedCost(component, locationData);
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
   * Get localized cost using cost hierarchy:
   * 1. Fresh retail prices (within 7 days)
   * 2. National average × location modifier
   */
  async getLocalizedCost(item, locationData) {
    // First, try to get fresh retail price
    if (locationData.location_id) {
      const retailResult = await db.query(`
        SELECT retail_price
        FROM contractorlens.RetailPrices
        WHERE item_id = $1 
          AND location_id = $2
          AND effective_date <= CURRENT_DATE
          AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
          AND last_scraped > NOW() - INTERVAL '${this.retailPriceFreshnessDays} days'
        ORDER BY last_scraped DESC
        LIMIT 1
      `, [item.item_id, locationData.location_id]);
      
      if (retailResult.rows.length > 0) {
        console.log(`Using retail price for ${item.description}: $${retailResult.rows[0].retail_price}`);
        return parseFloat(retailResult.rows[0].retail_price);
      }
    }
    
    // Fallback to national average with location modifier
    const nationalCost = parseFloat(item.national_average_cost) || 0;
    
    let modifier = 1.000;
    if (item.item_type === 'material') {
      modifier = parseFloat(locationData.material_modifier) || 1.000;
    } else if (item.item_type === 'labor') {
      modifier = parseFloat(locationData.labor_modifier) || 1.000;
    }
    
    const localizedCost = nationalCost * modifier;
    console.log(`Using localized cost for ${item.description}: $${nationalCost} × ${modifier} = $${localizedCost.toFixed(2)}`);
    
    return localizedCost;
  }

  /**
   * Add finish-level specific items that aren't in standard assemblies
   * These are premium finishes, fixtures, etc.
   */
  async selectFinishItems(finishLevel, takeoffData, locationData, userSettings) {
    const finishItems = [];
    
    // Query for finish-specific items
    const result = await db.query(`
      SELECT item_id, csi_code, description, unit, category,
             quantity_per_unit, national_average_cost, item_type
      FROM contractorlens.Items
      WHERE quality_tier = $1 
        AND category IN ('fixtures', 'finishes', 'appliances')
      ORDER BY category, csi_code
    `, [finishLevel]);
    
    // For each finish item, determine if it applies to this takeoff
    for (const item of result.rows) {
      const quantity = this.determineFinishItemQuantity(item, takeoffData);
      if (quantity > 0) {
        const localizedCost = await this.getLocalizedCost(item, locationData);
        const totalCost = quantity * localizedCost;
        
        finishItems.push({
          itemId: item.item_id,
          csiCode: item.csi_code,
          description: `${item.description} (${finishLevel} level)`,
          quantity: quantity,
          unit: item.unit,
          unitCost: localizedCost,
          totalCost: totalCost,
          type: item.item_type,
          category: item.category
        });
      }
    }
    
    return finishItems;
  }

  /**
   * Determine quantity needed for finish items based on takeoff data
   */
  determineFinishItemQuantity(item, takeoffData) {
    // Simple logic - in production this would be more sophisticated
    switch (item.category) {
      case 'fixtures':
        // Count rooms/bathrooms for fixtures
        return (takeoffData.bathrooms?.length || 0) + (takeoffData.kitchens?.length || 0);
        
      case 'appliances':
        // One set per kitchen
        return takeoffData.kitchens?.length || 0;
        
      case 'finishes':
        // Based on total area
        const totalArea = this.calculateTotalArea(takeoffData);
        return totalArea;
        
      default:
        return 0;
    }
  }

  /**
   * Calculate total area from takeoff data
   */
  calculateTotalArea(takeoffData) {
    let totalArea = 0;
    
    ['walls', 'floors', 'ceilings'].forEach(surface => {
      if (takeoffData[surface] && Array.isArray(takeoffData[surface])) {
        totalArea += takeoffData[surface].reduce((sum, item) => sum + (item.area || 0), 0);
      }
    });
    
    return totalArea;
  }

  /**
   * Apply user markup and taxes to get final pricing
   */
  applyMarkupAndTax(lineItems, subtotal, userSettings) {
    const markupPercentage = userSettings.markup_percentage || this.defaultMarkupPercentage;
    const taxRate = userSettings.tax_rate || this.defaultTaxRate;
    
    // Calculate totals by category
    const materialTotal = lineItems
      .filter(item => item.type === 'material' || item.type === 'equipment')
      .reduce((sum, item) => sum + item.totalCost, 0);
    
    const laborTotal = lineItems
      .filter(item => item.type === 'labor')
      .reduce((sum, item) => sum + item.totalCost, 0);
    
    // Apply markup
    const markupAmount = subtotal * (markupPercentage / 100);
    const afterMarkup = subtotal + markupAmount;
    
    // Apply taxes (typically only on materials)
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

module.exports = AssemblyEngine;