const db = require('../config/database');
const QuantityCalculator = require('./quantityCalculator');
const LaborCalculator = require('./laborCalculator');
const ProductCatalog = require('./productCatalog');

class AssemblyEngine {
  constructor() {
    this.defaultMarkupPercentage = parseFloat(process.env.DEFAULT_MARKUP_PERCENTAGE) || 25;
    this.defaultTaxRate = parseFloat(process.env.DEFAULT_TAX_RATE) || 0.08;
  }

  async calculateEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    try {
      this.validateInputs(takeoffData, jobType, finishLevel, zipCode, userSettings);
      const locationData = await this.getLocationData(zipCode);
      const assemblies = await this.getAssembliesForJobType(jobType);
      
      let lineItems = [];
      let totalLaborHours = 0;

      for (const assembly of assemblies) {
        const takeoffQuantity = this.matchTakeoffToAssembly(takeoffData, assembly);
        if (!takeoffQuantity || takeoffQuantity <= 0) continue;

        const assemblyItems = await this.getAssemblyItems(assembly.assembly_id);

        for (const component of assemblyItems) {
          const componentLineItem = await this.calculateComponentCost(
            component,
            takeoffQuantity,
            finishLevel,
            locationData,
            userSettings,
            takeoffData // Pass full takeoff data for context
          );
          if (componentLineItem) {
            lineItems.push(componentLineItem);
            if (componentLineItem.type === 'labor') {
              totalLaborHours += componentLineItem.labor_details.total_hours;
            }
          }
        }
      }

      const subtotal = lineItems.reduce((sum, item) => sum + item.total_cost, 0);
      const finalEstimate = this.applyMarkupAndTax(lineItems, subtotal, userSettings);

      // Organize results by CSI divisions
      const organizedEstimate = await this.organizeByCSIDivisions(finalEstimate);

      organizedEstimate.metadata = {
        totalLaborHours,
        finishLevel,
        location: locationData,
        calculationDate: new Date().toISOString(),
        engineVersion: '2.0' // Upped version for new granularity
      };

      return organizedEstimate;

    } catch (error) {
      console.error('Assembly Engine V2 calculation error:', error);
      throw new Error(`Estimate calculation failed: ${error.message}`);
    }
  }

  async calculateComponentCost(component, assemblyQuantity, finishLevel, locationData, userSettings, roomConditions) {
    if (component.quality_tier && component.quality_tier !== finishLevel) {
      return null;
    }

    const baseQuantity = assemblyQuantity * component.quantity;

    if (component.item_type === 'labor') {
      const laborResult = await LaborCalculator.calculateLaborHours(component, baseQuantity, { ...roomConditions, zipCode: locationData.zip_code });
      return {
        itemId: component.item_id,
        csiCode: component.csi_code,
        description: `${component.description} - Labor`,
        quantity: laborResult.total_hours,
        unit: 'hours',
        unitCost: laborResult.total_labor_cost / laborResult.total_hours,
        total_cost: laborResult.total_labor_cost,
        type: 'labor',
        category: component.category,
        labor_details: laborResult.labor_details
      };
    } else {
      const quantityResult = await QuantityCalculator.calculateMaterialQuantity(component, baseQuantity, roomConditions);
      const enrichedItem = await ProductCatalog.enrichItemWithSpecs(component);
      const localizedCost = await this.getLocalizedCost(component, locationData);
      const totalCost = quantityResult.total_quantity * localizedCost;

      return {
        itemId: component.item_id,
        csiCode: component.csi_code,
        description: enrichedItem.description,
        quantity: quantityResult.total_quantity,
        unit: component.unit,
        unitCost: localizedCost,
        total_cost: totalCost,
        type: component.item_type,
        category: component.category,
        manufacturer: enrichedItem.manufacturer,
        model_number: enrichedItem.model_number,
        specifications: enrichedItem.specifications,
        quantity_details: quantityResult
      };
    }
  }
  
  async organizeByCSIDivisions(estimate) {
    const divisions = {};

    for (const item of estimate.lineItems) {
      const trade = await this.getTradeForItem(item.itemId);
      if (!trade) continue;

      const divisionKey = `${trade.csi_division}_${trade.division_name}`;

      if (!divisions[divisionKey]) {
        divisions[divisionKey] = {
          csi_code: trade.csi_division,
          division_name: trade.division_name,
          total_cost: 0,
          labor_hours: 0,
          line_items: []
        };
      }

      divisions[divisionKey].line_items.push(item);
      divisions[divisionKey].total_cost += item.total_cost;
      if (item.type === 'labor') {
        divisions[divisionKey].labor_hours += item.quantity;
      }
    }

    estimate.csi_divisions = Object.values(divisions).sort((a, b) => a.csi_code.localeCompare(b.csi_code));
    delete estimate.lineItems; // Remove the flat list
    return estimate;
  }

  async getTradeForItem(itemId) {
    const result = await db.query(`
      SELECT t.*
      FROM contractorlens.Items i
      JOIN contractorlens.Trades t ON i.trade_id = t.trade_id
      WHERE i.item_id = $1
    `, [itemId]);
    return result.rows[0];
  }

  // ... (Keep all other existing methods like validateInputs, getLocationData, etc.)
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

  async getAssemblyItems(assemblyId) {
    const result = await db.query(`
      SELECT 
        ai.quantity,
        i.item_id, i.csi_code, i.description, i.unit, i.category,
        i.quantity_per_unit, i.quality_tier, i.national_average_cost,
        i.item_type, i.manufacturer, i.model_number
      FROM contractorlens.AssemblyItems ai
      JOIN contractorlens.Items i ON ai.item_id = i.item_id
      WHERE ai.assembly_id = $1
      ORDER BY i.item_type, i.csi_code
    `, [assemblyId]);
    
    return result.rows;
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
        return 0;
    }
  }

  async getLocalizedCost(item, locationData) {
    if (locationData.location_id) {
      const retailResult = await db.query(`
        SELECT retail_price
        FROM contractorlens.RetailPrices
        WHERE item_id = $1 
          AND location_id = $2
          AND effective_date <= CURRENT_DATE
          AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
          AND last_scraped > NOW() - INTERVAL '7 days'
        ORDER BY last_scraped DESC
        LIMIT 1
      `, [item.item_id, locationData.location_id]);
      
      if (retailResult.rows.length > 0) {
        return parseFloat(retailResult.rows[0].retail_price);
      }
    }
    
    const nationalCost = parseFloat(item.national_average_cost) || 0;
    let modifier = 1.000;
    if (item.item_type === 'material') {
      modifier = parseFloat(locationData.material_modifier) || 1.000;
    } else if (item.item_type === 'labor') {
      modifier = parseFloat(locationData.labor_modifier) || 1.000;
    }
    
    return nationalCost * modifier;
  }

  applyMarkupAndTax(lineItems, subtotal, userSettings) {
    const markupPercentage = userSettings.markup_percentage || this.defaultMarkupPercentage;
    const taxRate = userSettings.tax_rate || this.defaultTaxRate;
    
    const materialTotal = lineItems
      .filter(item => item.type === 'material' || item.type === 'equipment')
      .reduce((sum, item) => sum + item.total_cost, 0);
    
    const laborTotal = lineItems
      .filter(item => item.type === 'labor')
      .reduce((sum, item) => sum + item.total_cost, 0);
    
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
      grandTotal
    };
  }
}

module.exports = new AssemblyEngine();