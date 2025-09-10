class MeasurementEnricher {
  constructor() {
    this.standardRoomDimensions = {
      kitchen: { minArea: 70, maxArea: 300, typicalHeight: 8.5 },
      bathroom: { minArea: 25, maxArea: 120, typicalHeight: 8.0 },
      living_room: { minArea: 120, maxArea: 600, typicalHeight: 9.0 },
      bedroom: { minArea: 80, maxArea: 250, typicalHeight: 8.5 },
      dining_room: { minArea: 100, maxArea: 300, typicalHeight: 9.0 },
      office: { minArea: 60, maxArea: 200, typicalHeight: 8.5 },
      laundry_room: { minArea: 30, maxArea: 80, typicalHeight: 8.0 }
    };
  }

  enrichScanData(scanData) {
    const enrichedData = {
      ...scanData,
      measurement_analysis: this.analyzeMeasurements(scanData.dimensions, scanData.room_type),
      surface_calculations: this.calculateSurfaceAreas(scanData.dimensions),
      space_efficiency: this.assessSpaceEfficiency(scanData.dimensions, scanData.room_type),
      construction_context: this.addConstructionContext(scanData.dimensions, scanData.room_type)
    };

    return enrichedData;
  }

  analyzeMeasurements(dimensions, roomType) {
    const standards = this.standardRoomDimensions[roomType] || {};
    const area = dimensions.length * dimensions.width;
    
    return {
      area_sqft: area,
      area_category: this.categorizeArea(area, standards),
      proportions: this.analyzeProportions(dimensions),
      height_category: this.categorizeHeight(dimensions.height, standards),
      size_relative_to_typical: this.compareToTypical(area, standards),
      measurement_flags: this.identifyMeasurementFlags(dimensions, roomType)
    };
  }

  categorizeArea(area, standards) {
    if (!standards.minArea || !standards.maxArea) return 'unknown';
    
    if (area < standards.minArea) return 'below_standard';
    if (area > standards.maxArea) return 'above_standard';
    
    const midpoint = (standards.minArea + standards.maxArea) / 2;
    return area < midpoint ? 'compact' : 'spacious';
  }

  analyzeProportions(dimensions) {
    const ratio = Math.max(dimensions.length, dimensions.width) / Math.min(dimensions.length, dimensions.width);
    
    let shape;
    if (ratio < 1.2) shape = 'square';
    else if (ratio < 1.6) shape = 'rectangular';
    else if (ratio < 2.5) shape = 'elongated';
    else shape = 'narrow';

    return {
      length_to_width_ratio: ratio.toFixed(2),
      shape_description: shape,
      is_square: ratio < 1.2,
      longest_dimension: Math.max(dimensions.length, dimensions.width),
      shortest_dimension: Math.min(dimensions.length, dimensions.width)
    };
  }

  categorizeHeight(height, standards) {
    const typicalHeight = standards.typicalHeight || 8.5;
    
    if (height < 7.5) return 'low_ceiling';
    if (height < 8.0) return 'below_standard';
    if (height <= 9.0) return 'standard';
    if (height <= 10.0) return 'high_ceiling';
    return 'very_high_ceiling';
  }

  compareToTypical(area, standards) {
    if (!standards.minArea || !standards.maxArea) return 'unknown';
    
    const typicalArea = (standards.minArea + standards.maxArea) / 2;
    const variance = ((area - typicalArea) / typicalArea * 100).toFixed(1);
    
    return {
      percentage_difference: variance,
      comparison: area > typicalArea ? 'larger' : 'smaller',
      within_normal_range: area >= standards.minArea && area <= standards.maxArea
    };
  }

  identifyMeasurementFlags(dimensions, roomType) {
    const flags = [];
    const area = dimensions.length * dimensions.width;
    
    // Size-based flags
    if (area < 50) flags.push('very_small_space');
    if (area > 400) flags.push('very_large_space');
    
    // Proportion-based flags
    const ratio = Math.max(dimensions.length, dimensions.width) / Math.min(dimensions.length, dimensions.width);
    if (ratio > 3) flags.push('unusually_narrow');
    if (ratio < 1.1) flags.push('perfect_square');
    
    // Height-based flags
    if (dimensions.height < 7.5) flags.push('low_ceiling_challenges');
    if (dimensions.height > 10) flags.push('high_ceiling_opportunities');
    
    // Room-specific flags
    if (roomType === 'kitchen' && area < 80) flags.push('compact_kitchen_layout');
    if (roomType === 'bathroom' && area < 30) flags.push('powder_room_size');
    if (roomType === 'bedroom' && area < 70) flags.push('small_bedroom');
    
    return flags;
  }

  calculateSurfaceAreas(dimensions) {
    const floorArea = dimensions.length * dimensions.width;
    const ceilingArea = floorArea;
    
    // Wall areas (accounting for typical door/window openings)
    const perimeter = 2 * (dimensions.length + dimensions.width);
    const grossWallArea = perimeter * dimensions.height;
    
    // Estimate typical openings (doors ~20 sqft, windows ~15 sqft average)
    const estimatedOpenings = this.estimateOpenings(dimensions, floorArea);
    const netWallArea = grossWallArea - estimatedOpenings.total_opening_area;
    
    return {
      floor: {
        area_sqft: floorArea,
        perimeter_ft: perimeter
      },
      ceiling: {
        area_sqft: ceilingArea
      },
      walls: {
        gross_area_sqft: grossWallArea,
        net_area_sqft: Math.max(netWallArea, grossWallArea * 0.7), // Ensure reasonable minimum
        estimated_openings: estimatedOpenings
      },
      total_surface_area: floorArea + ceilingArea + netWallArea
    };
  }

  estimateOpenings(dimensions, floorArea) {
    // Basic estimation - could be enhanced with room-specific logic
    let doors = 1; // Minimum one door entry
    let windows = Math.floor(floorArea / 100); // Rough estimate: 1 window per 100 sqft
    
    // Room-specific adjustments would go here
    // For now, keep it simple
    
    const doorArea = doors * 20; // 20 sqft per door
    const windowArea = windows * 15; // 15 sqft per window
    
    return {
      estimated_doors: doors,
      estimated_windows: windows,
      door_area_sqft: doorArea,
      window_area_sqft: windowArea,
      total_opening_area: doorArea + windowArea
    };
  }

  assessSpaceEfficiency(dimensions, roomType) {
    const area = dimensions.length * dimensions.width;
    const perimeter = 2 * (dimensions.length + dimensions.width);
    const compactness = area / (perimeter * perimeter) * 16; // Normalized compactness index
    
    return {
      compactness_index: compactness.toFixed(3),
      efficiency_rating: this.rateEfficiency(compactness),
      wall_to_area_ratio: (perimeter / area).toFixed(2),
      space_utilization_potential: this.assessUtilization(dimensions, roomType)
    };
  }

  rateEfficiency(compactness) {
    // Higher compactness = more efficient use of perimeter
    if (compactness > 0.8) return 'highly_efficient';
    if (compactness > 0.6) return 'efficient';
    if (compactness > 0.4) return 'moderately_efficient';
    return 'inefficient';
  }

  assessUtilization(dimensions, roomType) {
    const area = dimensions.length * dimensions.width;
    const utilization = { challenges: [], opportunities: [] };
    
    // Universal space considerations
    if (Math.min(dimensions.length, dimensions.width) < 6) {
      utilization.challenges.push('narrow_dimension_limits_furniture');
    }
    
    if (dimensions.height < 8) {
      utilization.challenges.push('low_ceiling_limits_storage');
    } else if (dimensions.height > 9) {
      utilization.opportunities.push('high_ceiling_storage_potential');
    }
    
    // Room-specific utilization analysis
    switch (roomType) {
      case 'kitchen':
        if (area < 100) utilization.challenges.push('limited_counter_space');
        if (Math.min(dimensions.length, dimensions.width) > 8) {
          utilization.opportunities.push('island_installation_possible');
        }
        break;
        
      case 'bathroom':
        if (area < 35) utilization.challenges.push('tight_fixture_spacing');
        if (area > 80) utilization.opportunities.push('luxury_features_possible');
        break;
        
      case 'bedroom':
        if (area < 80) utilization.challenges.push('limited_furniture_options');
        if (Math.min(dimensions.length, dimensions.width) > 10) {
          utilization.opportunities.push('sitting_area_possible');
        }
        break;
    }
    
    return utilization;
  }

  addConstructionContext(dimensions, roomType) {
    const area = dimensions.length * dimensions.width;
    
    return {
      material_estimates: this.estimateMaterialQuantities(dimensions),
      access_considerations: this.assessAccess(dimensions),
      installation_complexity: this.assessInstallationComplexity(dimensions, roomType),
      cost_drivers: this.identifyCostDrivers(dimensions, roomType)
    };
  }

  estimateMaterialQuantities(dimensions) {
    const floorArea = dimensions.length * dimensions.width;
    const wallArea = 2 * (dimensions.length + dimensions.width) * dimensions.height;
    const ceilingArea = floorArea;
    
    // Add typical waste factors
    return {
      flooring_sqft: Math.ceil(floorArea * 1.1), // 10% waste factor
      wall_material_sqft: Math.ceil(wallArea * 0.85), // Account for openings
      ceiling_material_sqft: Math.ceil(ceilingArea * 1.05), // 5% waste factor
      trim_linear_ft: Math.ceil(2 * (dimensions.length + dimensions.width) * 1.1)
    };
  }

  assessAccess(dimensions) {
    return {
      material_delivery: dimensions.length < 8 || dimensions.width < 8 ? 'challenging' : 'standard',
      equipment_access: Math.min(dimensions.length, dimensions.width) < 6 ? 'limited' : 'adequate',
      workspace_availability: dimensions.length * dimensions.width > 100 ? 'spacious' : 'compact'
    };
  }

  assessInstallationComplexity(dimensions, roomType) {
    let complexity = 'standard';
    const factors = [];
    
    // Size-based complexity
    if (dimensions.length * dimensions.width < 50) {
      complexity = 'challenging';
      factors.push('small_working_space');
    }
    
    // Shape-based complexity
    const ratio = Math.max(dimensions.length, dimensions.width) / Math.min(dimensions.length, dimensions.width);
    if (ratio > 2.5) {
      complexity = 'challenging';
      factors.push('narrow_room_layout');
    }
    
    // Height-based complexity
    if (dimensions.height > 10) {
      factors.push('high_ceiling_access');
    } else if (dimensions.height < 7.5) {
      factors.push('low_ceiling_constraints');
    }
    
    return { level: complexity, factors };
  }

  identifyCostDrivers(dimensions, roomType) {
    const drivers = [];
    
    // Size drivers
    const area = dimensions.length * dimensions.width;
    if (area > 300) drivers.push('large_area_material_costs');
    if (area < 50) drivers.push('small_area_labor_inefficiency');
    
    // Access drivers
    if (Math.min(dimensions.length, dimensions.width) < 6) {
      drivers.push('access_limitations_increase_labor');
    }
    
    // Height drivers
    if (dimensions.height > 9) {
      drivers.push('high_ceiling_equipment_rental');
    }
    
    return drivers;
  }

  // Utility method for external integrations
  createMeasurementSummary(scanData) {
    const enriched = this.enrichScanData(scanData);
    
    return {
      room_type: scanData.room_type,
      basic_dimensions: scanData.dimensions,
      area_analysis: enriched.measurement_analysis,
      construction_summary: {
        complexity: enriched.construction_context.installation_complexity.level,
        key_factors: enriched.construction_context.installation_complexity.factors,
        space_efficiency: enriched.space_efficiency.efficiency_rating
      },
      recommendations: this.generateMeasurementRecommendations(enriched)
    };
  }

  generateMeasurementRecommendations(enrichedData) {
    const recommendations = [];
    
    // Based on size category
    const sizeCategory = enrichedData.measurement_analysis.area_category;
    if (sizeCategory === 'compact') {
      recommendations.push('Consider space-saving fixtures and built-ins');
    } else if (sizeCategory === 'spacious') {
      recommendations.push('Opportunity for premium features and custom installations');
    }
    
    // Based on proportions
    if (enrichedData.measurement_analysis.proportions.shape_description === 'narrow') {
      recommendations.push('Linear layout designs will work best');
    }
    
    // Based on ceiling height
    const heightCategory = enrichedData.measurement_analysis.height_category;
    if (heightCategory === 'high_ceiling') {
      recommendations.push('Consider vertical storage and dramatic lighting options');
    }
    
    return recommendations;
  }
}

module.exports = MeasurementEnricher;