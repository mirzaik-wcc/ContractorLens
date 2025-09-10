const GeminiDigitalSurveyor = require('../../../ml-services/gemini-service/analyzer');
const AssemblyEngine = require('./assemblyEngine');
const Joi = require('joi');

/**
 * Gemini Integration Service
 * 
 * Bridges the ML Gemini analysis with the Assembly Engine for enhanced estimates.
 * 
 * Flow:
 * 1. AR scan produces takeoff data + images
 * 2. Gemini analyzes images → material/condition identification  
 * 3. This service combines Gemini insights with takeoff data
 * 4. Enhanced data feeds into Assembly Engine for accurate estimates
 */
class GeminiIntegrationService {
  constructor() {
    this.geminiSurveyor = new GeminiDigitalSurveyor();
    this.assemblyEngine = new AssemblyEngine();
    this.initialized = false;
  }

  async initialize() {
    if (this.initialized) return;
    
    await this.geminiSurveyor.initialize();
    this.initialized = true;
    console.log('Gemini Integration Service initialized');
  }

  /**
   * Enhanced estimate workflow combining AR + AI analysis
   * 
   * @param {Object} enhancedScanData - Combined AR takeoff + image frames
   * @param {string} finishLevel - User preference (good/better/best)
   * @param {string} zipCode - Location for cost calculations
   * @param {Object} userSettings - User markup/tax preferences
   * @returns {Object} Enhanced estimate with AI insights
   */
  async createEnhancedEstimate(enhancedScanData, finishLevel, zipCode, userSettings) {
    await this.initialize();

    try {
      console.log(`Creating enhanced estimate with Gemini analysis for ${enhancedScanData.room_type}`);

      // Step 1: Validate input data
      this.validateEnhancedScanData(enhancedScanData);

      // Step 2: Run Gemini analysis on the room images
      console.log('Running Gemini room analysis...');
      const geminiAnalysis = await this.geminiSurveyor.analyzeScan(enhancedScanData);

      // Step 3: Enhance takeoff data with Gemini insights
      console.log('Enhancing takeoff data with AI insights...');
      const enhancedTakeoffData = this.enhanceTakeoffData(
        enhancedScanData.takeoff_data,
        geminiAnalysis
      );

      // Step 4: Determine optimal job type and finish level
      const optimizedJobType = this.determineOptimalJobType(geminiAnalysis);
      const recommendedFinishLevel = this.recommendFinishLevel(
        geminiAnalysis, 
        finishLevel, 
        userSettings
      );

      // Step 5: Run Assembly Engine with enhanced data
      console.log('Calculating estimate with Assembly Engine...');
      const estimate = await this.assemblyEngine.calculateEstimate(
        enhancedTakeoffData,
        optimizedJobType,
        recommendedFinishLevel,
        zipCode,
        userSettings
      );

      // Step 6: Add AI analysis metadata to estimate
      return this.enrichEstimateWithAnalysis(estimate, geminiAnalysis, enhancedScanData);

    } catch (error) {
      console.error('Enhanced estimate creation failed:', error);
      throw new Error(`Failed to create enhanced estimate: ${error.message}`);
    }
  }

  /**
   * Validate the enhanced scan data structure
   */
  validateEnhancedScanData(scanData) {
    const schema = Joi.object({
      scan_id: Joi.string().required(),
      room_type: Joi.string().valid('kitchen', 'bathroom', 'living_room', 'bedroom', 'dining_room', 'office', 'laundry_room').required(),
      
      // AR takeoff data (from RoomPlan)
      takeoff_data: Joi.object({
        walls: Joi.array().items(Joi.object({
          area: Joi.number().positive().required(),
          height: Joi.number().positive().optional(),
          type: Joi.string().optional()
        })).optional(),
        floors: Joi.array().items(Joi.object({
          area: Joi.number().positive().required(),
          type: Joi.string().optional()
        })).optional(),
        ceilings: Joi.array().items(Joi.object({
          area: Joi.number().positive().required(),
          type: Joi.string().optional()
        })).optional(),
        kitchens: Joi.array().items(Joi.object({
          area: Joi.number().positive().required()
        })).optional(),
        bathrooms: Joi.array().items(Joi.object({
          area: Joi.number().positive().required()
        })).optional()
      }).required(),

      // Room dimensions from AR
      dimensions: Joi.object({
        length: Joi.number().positive().required(),
        width: Joi.number().positive().required(), 
        height: Joi.number().positive().required(),
        total_area: Joi.number().positive().required()
      }).required(),

      // Image frames for Gemini analysis
      frames: Joi.array().items(
        Joi.object({
          timestamp: Joi.string().required(),
          imageData: Joi.string().required(),
          mimeType: Joi.string().default('image/jpeg'),
          cameraPosition: Joi.object().optional(),
          lighting_conditions: Joi.string().optional()
        })
      ).min(1).max(20).required(),

      // Optional surface detection from AR
      surfaces_detected: Joi.array().items(
        Joi.object({
          type: Joi.string().valid('floor', 'wall', 'ceiling').required(),
          area: Joi.number().positive().required()
        })
      ).optional(),

      start_time: Joi.number().optional()
    });

    const { error } = schema.validate(scanData);
    if (error) {
      throw new Error(`Invalid enhanced scan data: ${error.message}`);
    }
  }

  /**
   * Enhance basic takeoff data with Gemini analysis insights
   */
  enhanceTakeoffData(takeoffData, geminiAnalysis) {
    const enhanced = JSON.parse(JSON.stringify(takeoffData)); // Deep clone

    // Add material and condition insights to surfaces
    if (enhanced.walls) {
      enhanced.walls = enhanced.walls.map(wall => ({
        ...wall,
        current_material: geminiAnalysis.surfaces.walls.primary_material,
        condition: geminiAnalysis.surfaces.walls.condition,
        repair_needed: geminiAnalysis.surfaces.walls.repair_needed,
        complexity_modifier: this.calculateComplexityModifier(
          geminiAnalysis.complexity_factors, 'walls'
        )
      }));
    }

    if (enhanced.floors) {
      enhanced.floors = enhanced.floors.map(floor => ({
        ...floor,
        current_material: geminiAnalysis.surfaces.flooring.current_material,
        condition: geminiAnalysis.surfaces.flooring.condition,
        removal_required: geminiAnalysis.surfaces.flooring.removal_required,
        subfloor_condition: geminiAnalysis.surfaces.flooring.subfloor_condition,
        recommended_materials: geminiAnalysis.surfaces.flooring.recommendations,
        complexity_modifier: this.calculateComplexityModifier(
          geminiAnalysis.complexity_factors, 'flooring'
        )
      }));
    }

    if (enhanced.ceilings) {
      enhanced.ceilings = enhanced.ceilings.map(ceiling => ({
        ...ceiling,
        current_material: geminiAnalysis.surfaces.ceiling.material,
        condition: geminiAnalysis.surfaces.ceiling.condition,
        height_standard: geminiAnalysis.surfaces.ceiling.height_standard,
        complexity_modifier: this.calculateComplexityModifier(
          geminiAnalysis.complexity_factors, 'ceiling'
        )
      }));
    }

    // Add room-specific enhancements
    if (geminiAnalysis.room_type === 'kitchen' && enhanced.kitchens) {
      enhanced.kitchens = enhanced.kitchens.map(kitchen => ({
        ...kitchen,
        utilities_present: geminiAnalysis.complexity_factors.utilities_present,
        moisture_concerns: geminiAnalysis.complexity_factors.moisture_concerns,
        ventilation_adequate: geminiAnalysis.complexity_factors.ventilation_adequate,
        suggested_assemblies: geminiAnalysis.assembly_recommendations.suggested_assemblies
      }));
    }

    if (geminiAnalysis.room_type === 'bathroom' && enhanced.bathrooms) {
      enhanced.bathrooms = enhanced.bathrooms.map(bathroom => ({
        ...bathroom,
        utilities_present: geminiAnalysis.complexity_factors.utilities_present,
        moisture_concerns: geminiAnalysis.complexity_factors.moisture_concerns,
        ventilation_adequate: geminiAnalysis.complexity_factors.ventilation_adequate,
        suggested_assemblies: geminiAnalysis.assembly_recommendations.suggested_assemblies
      }));
    }

    // Add global complexity factors
    enhanced.complexity_analysis = {
      accessibility: geminiAnalysis.complexity_factors.accessibility,
      structural_considerations: geminiAnalysis.complexity_factors.structural_considerations,
      overall_complexity: this.assessOverallComplexity(geminiAnalysis.complexity_factors)
    };

    return enhanced;
  }

  /**
   * Calculate complexity modifier based on Gemini analysis
   */
  calculateComplexityModifier(complexityFactors, surface) {
    let modifier = 1.0;

    // Accessibility impact
    switch (complexityFactors.accessibility) {
      case 'challenging':
        modifier *= 1.15;
        break;
      case 'very_difficult':
        modifier *= 1.3;
        break;
    }

    // Surface-specific factors
    if (surface === 'flooring' && complexityFactors.moisture_concerns) {
      modifier *= 1.1; // Additional waterproofing work
    }

    if (surface === 'walls' && complexityFactors.utilities_present.length > 0) {
      modifier *= 1.05 + (complexityFactors.utilities_present.length * 0.02);
    }

    if (surface === 'ceiling' && !complexityFactors.ventilation_adequate) {
      modifier *= 1.08; // HVAC work needed
    }

    // Structural considerations
    if (complexityFactors.structural_considerations && 
        complexityFactors.structural_considerations.length > 0) {
      modifier *= 1.1;
    }

    return Math.min(modifier, 1.5); // Cap at 50% increase
  }

  /**
   * Assess overall project complexity
   */
  assessOverallComplexity(complexityFactors) {
    let score = 0;

    // Accessibility scoring
    switch (complexityFactors.accessibility) {
      case 'standard': score += 1; break;
      case 'challenging': score += 2; break;
      case 'very_difficult': score += 3; break;
    }

    // Utilities complexity
    score += complexityFactors.utilities_present.length;

    // Structural complexity
    if (complexityFactors.structural_considerations) {
      score += complexityFactors.structural_considerations.length;
    }

    // Environmental factors
    if (complexityFactors.moisture_concerns) score += 1;
    if (!complexityFactors.ventilation_adequate) score += 1;

    // Map score to complexity level
    if (score <= 2) return 'low';
    if (score <= 5) return 'medium';
    return 'high';
  }

  /**
   * Determine optimal job type based on Gemini analysis
   */
  determineOptimalJobType(geminiAnalysis) {
    // Primary mapping from room type
    const roomTypeMapping = {
      'kitchen': 'kitchen',
      'bathroom': 'bathroom',
      'living_room': 'room',
      'bedroom': 'room',
      'dining_room': 'room',
      'office': 'room',
      'laundry_room': 'room'
    };

    let jobType = roomTypeMapping[geminiAnalysis.room_type] || 'room';

    // Refine based on assembly recommendations
    if (geminiAnalysis.assembly_recommendations.suggested_assemblies) {
      const suggestions = geminiAnalysis.assembly_recommendations.suggested_assemblies;
      
      // Look for more specific job types in recommendations
      if (suggestions.some(s => s.includes('flooring'))) {
        jobType = 'flooring';
      } else if (suggestions.some(s => s.includes('wall'))) {
        jobType = 'wall';
      } else if (suggestions.some(s => s.includes('ceiling'))) {
        jobType = 'ceiling';
      }
    }

    return jobType;
  }

  /**
   * Recommend finish level based on analysis and user preference
   */
  recommendFinishLevel(geminiAnalysis, userPreference, userSettings) {
    // Start with user preference
    let recommendedLevel = userPreference;

    // Adjust based on current conditions
    const overallCondition = this.assessOverallCondition(geminiAnalysis.surfaces);
    
    if (overallCondition === 'poor' && userPreference === 'good') {
      // Recommend upgrading from good to better for poor conditions
      console.log('Recommending finish level upgrade due to poor existing conditions');
      recommendedLevel = 'better';
    }

    if (overallCondition === 'excellent' && userPreference === 'best') {
      // Existing conditions support premium work
      console.log('Existing conditions support premium finish level');
    }

    // Consider user budget indirectly through settings
    if (userSettings.markup_percentage < 15 && recommendedLevel === 'best') {
      console.log('Considering budget constraints, recommending better tier');
      recommendedLevel = 'better';
    }

    return recommendedLevel;
  }

  /**
   * Assess overall condition across all surfaces
   */
  assessOverallCondition(surfaces) {
    const conditions = [
      surfaces.flooring.condition,
      surfaces.walls.condition,
      surfaces.ceiling.condition
    ];

    const conditionScores = {
      'excellent': 4,
      'good': 3,
      'fair': 2,
      'poor': 1
    };

    const avgScore = conditions.reduce((sum, condition) => 
      sum + (conditionScores[condition] || 2), 0) / conditions.length;

    if (avgScore >= 3.5) return 'excellent';
    if (avgScore >= 2.5) return 'good';
    if (avgScore >= 1.5) return 'fair';
    return 'poor';
  }

  /**
   * Enrich the Assembly Engine estimate with AI analysis data
   */
  enrichEstimateWithAnalysis(estimate, geminiAnalysis, originalScanData) {
    return {
      ...estimate,
      
      // Add AI analysis section
      ai_analysis: {
        room_analysis: {
          room_type: geminiAnalysis.room_type,
          dimensions_validated: geminiAnalysis.dimensions_validated,
          overall_condition: this.assessOverallCondition(geminiAnalysis.surfaces),
          complexity_level: this.assessOverallComplexity(geminiAnalysis.complexity_factors)
        },
        
        surface_insights: {
          flooring: {
            current: geminiAnalysis.surfaces.flooring.current_material,
            condition: geminiAnalysis.surfaces.flooring.condition,
            removal_required: geminiAnalysis.surfaces.flooring.removal_required,
            recommendations: geminiAnalysis.surfaces.flooring.recommendations
          },
          walls: {
            material: geminiAnalysis.surfaces.walls.primary_material,
            condition: geminiAnalysis.surfaces.walls.condition,
            repairs_needed: geminiAnalysis.surfaces.walls.repair_needed.length
          },
          ceiling: {
            material: geminiAnalysis.surfaces.ceiling.material,
            condition: geminiAnalysis.surfaces.ceiling.condition,
            standard_height: geminiAnalysis.surfaces.ceiling.height_standard
          }
        },

        complexity_factors: geminiAnalysis.complexity_factors,
        
        assembly_recommendations: {
          suggested: geminiAnalysis.assembly_recommendations.suggested_assemblies,
          rationale: geminiAnalysis.assembly_recommendations.quality_tier_rationale,
          customizations: geminiAnalysis.assembly_recommendations.customization_needed || []
        }
      },

      // Enhanced metadata
      metadata: {
        ...estimate.metadata,
        ai_enhanced: true,
        gemini_model: geminiAnalysis.metadata?.model_version,
        analysis_confidence: this.calculateAnalysisConfidence(geminiAnalysis),
        frames_analyzed: geminiAnalysis.metadata?.frame_count,
        scan_id: originalScanData.scan_id
      }
    };
  }

  /**
   * Calculate confidence score for the analysis
   */
  calculateAnalysisConfidence(geminiAnalysis) {
    let confidence = 0.8; // Base confidence

    // Reduce confidence for fallback analyses
    if (geminiAnalysis.fallback_info) {
      confidence = 0.3;
    }

    // Adjust based on frame count
    const frameCount = geminiAnalysis.metadata?.frame_count || 1;
    if (frameCount >= 5) confidence += 0.1;
    if (frameCount >= 10) confidence += 0.05;

    // Cap at 0.95
    return Math.min(confidence, 0.95);
  }

  /**
   * Fallback method for when Gemini analysis fails
   */
  async createFallbackEstimate(takeoffData, jobType, finishLevel, zipCode, userSettings) {
    console.warn('Creating fallback estimate without Gemini analysis');
    
    // Use basic Assembly Engine without AI enhancements
    return await this.assemblyEngine.calculateEstimate(
      takeoffData,
      jobType,
      finishLevel,
      zipCode,
      userSettings
    );
  }

  /**
   * Health check for the integration service
   */
  async healthCheck() {
    const health = {
      service: 'gemini-integration',
      status: 'healthy',
      components: {}
    };

    try {
      // Check Gemini service
      const geminiStats = this.geminiSurveyor.getProcessingStats();
      health.components.gemini = {
        status: geminiStats.initialized ? 'healthy' : 'initializing',
        model: geminiStats.model,
        prompts_loaded: geminiStats.prompts_loaded
      };

      // Check Assembly Engine (basic validation)
      health.components.assembly_engine = {
        status: 'healthy',
        version: '1.0'
      };

    } catch (error) {
      health.status = 'degraded';
      health.error = error.message;
    }

    return health;
  }
}

module.exports = GeminiIntegrationService;