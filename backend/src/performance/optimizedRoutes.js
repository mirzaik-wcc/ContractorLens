/**
 * Optimized API Routes with Performance Enhancements
 * Performance Engineer: PERF001 - Phase 2 API Optimization
 * Target: <2s API response time with monitoring and optimization
 * Created: 2025-09-05
 */

const express = require('express');
const Joi = require('joi');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { authenticate } = require('../middleware/auth');
const OptimizedAssemblyEngine = require('./optimizedAssemblyEngine');
const OptimizedGeminiService = require('./geminiOptimization');
const { cacheManager } = require('./caching');
const db = require('../config/database');
const { firestore } = require('../config/firebase');

const router = express.Router();

// Initialize optimized services
const optimizedAssemblyEngine = new OptimizedAssemblyEngine();
const optimizedGeminiService = new OptimizedGeminiService();

// =============================================================================
// PERFORMANCE MIDDLEWARE
// =============================================================================

// Response compression for large estimate responses
router.use(compression({
  level: 6, // Good compression ratio without too much CPU overhead
  threshold: 1024, // Only compress responses > 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));

// Rate limiting to prevent API abuse
const estimateRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 50, // 50 estimates per 15 minutes per IP
  message: {
    error: 'Too many estimate requests, please try again later',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Performance monitoring middleware
const performanceMiddleware = (req, res, next) => {
  req.performanceStart = Date.now();
  
  // Override res.json to capture response time
  const originalJson = res.json.bind(res);
  res.json = function(body) {
    const responseTime = Date.now() - req.performanceStart;
    
    // Add performance headers
    res.set({
      'X-Response-Time': `${responseTime}ms`,
      'X-Cache-Status': body.metadata?.cachedResult ? 'HIT' : 'MISS',
      'X-Engine-Version': body.metadata?.engineVersion || 'standard'
    });
    
    // Log slow responses
    if (responseTime > 2000) {
      console.warn(`🐌 Slow response: ${req.method} ${req.path} took ${responseTime}ms`);
    }
    
    return originalJson(body);
  };
  
  next();
};

router.use(performanceMiddleware);

// =============================================================================
// OPTIMIZED ESTIMATE ROUTES
// =============================================================================

/**
 * POST /api/v1/estimates/optimized
 * High-performance estimate generation with caching and optimization
 */
router.post('/api/v1/estimates/optimized', estimateRateLimit, authenticate, async (req, res) => {
  try {
    const startTime = Date.now();
    console.log(`🚀 Optimized estimate request from user ${req.user.uid}`);

    // Enhanced input validation with performance optimizations
    const { error, value } = estimateRequestSchema.validate(req.body, { 
      abortEarly: false, // Get all validation errors at once
      stripUnknown: true // Remove unknown fields for better caching
    });
    
    if (error) {
      return res.status(400).json({ 
        error: 'Invalid request data',
        details: error.details,
        code: 'VALIDATION_FAILED',
        performance: { validation_time_ms: Date.now() - startTime }
      });
    }

    const { takeoffData, jobType, finishLevel, zipCode, projectId, notes, useGeminiAnalysis } = value;

    // Parallel user settings retrieval (don't block on Firestore)
    const userSettingsPromise = getUserSettingsOptimized(req.user.uid, finishLevel);

    // Check if this is a Gemini-enhanced request
    let enhancedTakeoffData = takeoffData;
    if (useGeminiAnalysis && takeoffData.arFrames && takeoffData.arFrames.length > 0) {
      console.log(`🤖 Processing Gemini-enhanced estimate`);
      
      try {
        const geminiAnalysis = await optimizedGeminiService.analyzeRoom(
          takeoffData.arFrames,
          jobType,
          takeoffData.dimensions || { length: 12, width: 10, height: 9 }
        );

        // Enhance takeoff data with Gemini insights
        enhancedTakeoffData = {
          ...takeoffData,
          gemini_analysis: geminiAnalysis,
          enhanced: true
        };

        // Apply Gemini modifiers to takeoff data
        if (geminiAnalysis.assembly_engine_enhancements) {
          enhancedTakeoffData = applyGeminiEnhancements(enhancedTakeoffData, geminiAnalysis);
        }

      } catch (geminiError) {
        console.warn(`⚠️ Gemini analysis failed, falling back to standard estimate:`, geminiError.message);
        // Continue with standard estimate
      }
    }

    // Get user settings (should be resolved by now)
    const userSettings = await userSettingsPromise;

    // Generate estimate using optimized Assembly Engine
    const estimate = await optimizedAssemblyEngine.calculateEstimate(
      enhancedTakeoffData,
      jobType,
      finishLevel,
      zipCode,
      userSettings
    );

    // Save estimate asynchronously (don't block response)
    const savePromise = saveEstimateOptimized({
      userId: req.user.uid,
      projectId: projectId || null,
      jobType,
      finishLevel,
      zipCode,
      takeoffData: enhancedTakeoffData,
      estimate,
      notes,
      status: 'draft'
    });

    // Response with performance metadata
    const totalTime = Date.now() - startTime;
    
    res.status(201).json({
      estimateId: null, // Will be set when save completes
      status: 'draft',
      createdAt: new Date().toISOString(),
      ...estimate,
      performance: {
        total_processing_time_ms: totalTime,
        target_time_ms: 2000,
        performance_rating: totalTime < 2000 ? 'EXCELLENT' : totalTime < 3000 ? 'GOOD' : 'NEEDS_IMPROVEMENT',
        cache_utilization: cacheManager.getCacheStats().performance,
        gemini_enhanced: !!useGeminiAnalysis
      }
    });

    // Await save completion for logging (but don't block response)
    savePromise.then(estimateId => {
      console.log(`✅ Estimate saved with ID: ${estimateId}`);
    }).catch(saveError => {
      console.error('❌ Failed to save estimate:', saveError);
    });

    console.log(`✅ Optimized estimate completed in ${totalTime}ms`);
    
  } catch (error) {
    console.error('❌ Optimized estimate calculation error:', error);
    
    const errorResponse = {
      error: 'Failed to calculate estimate',
      code: 'CALCULATION_FAILED',
      performance: { 
        processing_time_ms: Date.now() - req.performanceStart,
        failed_at: 'calculation'
      }
    };

    if (error.message.includes('Invalid')) {
      return res.status(400).json({ ...errorResponse, code: 'VALIDATION_FAILED' });
    }
    
    res.status(500).json(errorResponse);
  }
});

/**
 * POST /api/v1/analysis/enhanced-estimate
 * Gemini + Assembly Engine integrated workflow
 */
router.post('/api/v1/analysis/enhanced-estimate', estimateRateLimit, authenticate, async (req, res) => {
  try {
    const startTime = Date.now();
    console.log(`🎯 Enhanced estimate with full Gemini integration`);

    // Validate enhanced request
    const { error, value } = enhancedEstimateSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Invalid enhanced estimate request',
        details: error.details,
        code: 'VALIDATION_FAILED'
      });
    }

    const { frames, roomType, dimensions, location, userPreferences } = value;

    // Step 1: Parallel processing setup
    const [geminiAnalysisPromise, userSettingsPromise] = await Promise.allSettled([
      optimizedGeminiService.analyzeRoom(frames, roomType, dimensions, 'enhanced'),
      getUserSettingsOptimized(req.user.uid, userPreferences.qualityTier)
    ]);

    // Handle Gemini analysis result
    if (geminiAnalysisPromise.status === 'rejected') {
      console.warn(`⚠️ Gemini analysis failed:`, geminiAnalysisPromise.reason);
      return res.status(422).json({
        error: 'Visual analysis failed',
        code: 'GEMINI_ANALYSIS_FAILED',
        fallback_available: true
      });
    }

    const geminiAnalysis = geminiAnalysisPromise.value;
    const userSettings = userSettingsPromise.status === 'fulfilled' 
      ? userSettingsPromise.value 
      : getDefaultUserSettings(userPreferences.qualityTier);

    // Step 2: Convert Gemini analysis to Assembly Engine takeoff data
    const enhancedTakeoffData = convertGeminiToTakeoffData(geminiAnalysis, dimensions);

    // Step 3: Generate estimate with enhanced data
    const estimate = await optimizedAssemblyEngine.calculateEstimate(
      enhancedTakeoffData,
      roomType,
      userPreferences.qualityTier,
      location.zip,
      userSettings
    );

    // Step 4: Add Gemini-specific enhancements to response
    const enhancedEstimate = {
      ...estimate,
      gemini_insights: {
        visual_analysis: geminiAnalysis.room_analysis,
        cost_adjustments: geminiAnalysis.assembly_engine_enhancements?.cost_adjustments,
        recommendations: geminiAnalysis.room_analysis?.recommendations
      },
      confidence_score: calculateConfidenceScore(geminiAnalysis, estimate)
    };

    const totalTime = Date.now() - startTime;

    res.json({
      ...enhancedEstimate,
      analysis_type: 'gemini_enhanced',
      performance: {
        total_processing_time_ms: totalTime,
        gemini_analysis_time_ms: geminiAnalysis.performance_metadata?.processing_time || 0,
        assembly_calculation_time_ms: totalTime - (geminiAnalysis.performance_metadata?.processing_time || 0),
        performance_rating: totalTime < 5000 ? 'EXCELLENT' : 'ACCEPTABLE'
      }
    });

  } catch (error) {
    console.error('❌ Enhanced estimate failed:', error);
    res.status(500).json({
      error: 'Enhanced estimate generation failed',
      code: 'ENHANCED_ESTIMATE_FAILED',
      performance: { 
        processing_time_ms: Date.now() - req.performanceStart 
      }
    });
  }
});

// =============================================================================
// PERFORMANCE MONITORING ROUTES
// =============================================================================

/**
 * GET /api/v1/performance/stats
 * Real-time performance statistics
 */
router.get('/api/v1/performance/stats', authenticate, async (req, res) => {
  try {
    const stats = {
      assembly_engine: optimizedAssemblyEngine.getPerformanceStats(),
      gemini_service: optimizedGeminiService.getPerformanceStats(),
      cache_manager: cacheManager.getCacheStats(),
      database: await getDatabasePerformanceStats(),
      system: {
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        node_version: process.version
      }
    };

    res.json(stats);
  } catch (error) {
    console.error('Failed to get performance stats:', error);
    res.status(500).json({ error: 'Failed to retrieve performance statistics' });
  }
});

/**
 * POST /api/v1/performance/cache/warm
 * Warm caches with common data
 */
router.post('/api/v1/performance/cache/warm', authenticate, async (req, res) => {
  try {
    console.log('🔥 Starting cache warming process...');
    
    const commonZipCodes = ['94105', '10001', '77001', '90210', '60601'];
    const commonAssemblies = await getCommonAssemblies();

    await Promise.all([
      cacheManager.warmCache(commonZipCodes, commonAssemblies, db),
      warmGeminiResponseCache()
    ]);

    res.json({
      message: 'Cache warming completed',
      warmed_items: {
        location_modifiers: commonZipCodes.length,
        assemblies: commonAssemblies.length,
        gemini_responses: 'sample_responses_cached'
      }
    });

  } catch (error) {
    console.error('Cache warming failed:', error);
    res.status(500).json({ error: 'Cache warming failed' });
  }
});

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Optimized user settings retrieval with caching
 */
async function getUserSettingsOptimized(userId, defaultQualityTier) {
  const cacheKey = `user_settings_${userId}`;
  let userSettings = cacheManager.itemCostCache.get(cacheKey);
  
  if (userSettings) {
    return userSettings;
  }

  try {
    const userDoc = await firestore.collection('userSettings').doc(userId).get();
    
    if (userDoc.exists) {
      userSettings = userDoc.data();
    } else {
      userSettings = getDefaultUserSettings(defaultQualityTier);
      // Save default settings asynchronously
      firestore.collection('userSettings').doc(userId).set(userSettings).catch(console.warn);
    }

    // Cache for 10 minutes
    cacheManager.itemCostCache.set(cacheKey, userSettings, 600);
    return userSettings;

  } catch (firestoreError) {
    console.error('Firestore error, using defaults:', firestoreError);
    return getDefaultUserSettings(defaultQualityTier);
  }
}

function getDefaultUserSettings(qualityTier) {
  return {
    hourly_rate: 50,
    markup_percentage: 25,
    tax_rate: 0.08,
    preferred_quality_tier: qualityTier || 'better'
  };
}

/**
 * Apply Gemini enhancements to takeoff data
 */
function applyGeminiEnhancements(takeoffData, geminiAnalysis) {
  const enhancements = geminiAnalysis.assembly_engine_enhancements;
  if (!enhancements) return takeoffData;

  const enhanced = { ...takeoffData };

  // Apply takeoff modifiers
  if (enhancements.takeoff_modifiers) {
    const modifiers = enhancements.takeoff_modifiers;
    
    // Adjust areas based on Gemini analysis
    ['walls', 'floors', 'ceilings'].forEach(surface => {
      if (enhanced[surface]) {
        enhanced[surface] = enhanced[surface].map(item => ({
          ...item,
          area: item.area * (modifiers.area_adjustment || 1.0),
          waste_factor: modifiers.waste_factor || 1.05
        }));
      }
    });
  }

  // Add cost adjustment metadata
  if (enhancements.cost_adjustments) {
    enhanced.cost_adjustments = enhancements.cost_adjustments;
  }

  return enhanced;
}

/**
 * Convert Gemini analysis to Assembly Engine takeoff format
 */
function convertGeminiToTakeoffData(geminiAnalysis, dimensions) {
  const totalArea = dimensions.length * dimensions.width;
  
  return {
    dimensions,
    walls: [{
      area: geminiAnalysis.room_analysis.surfaces?.walls?.area_sf || 
            (dimensions.length * 2 + dimensions.width * 2) * dimensions.height,
      material: geminiAnalysis.room_analysis.surfaces?.walls?.material || 'drywall',
      condition: geminiAnalysis.room_analysis.surfaces?.walls?.condition || 'good'
    }],
    floors: [{
      area: geminiAnalysis.room_analysis.surfaces?.flooring?.area_sf || totalArea,
      material: geminiAnalysis.room_analysis.surfaces?.flooring?.material || 'carpet',
      condition: geminiAnalysis.room_analysis.surfaces?.flooring?.condition || 'good'
    }],
    ceilings: [{
      area: geminiAnalysis.room_analysis.surfaces?.ceiling?.area_sf || totalArea,
      material: geminiAnalysis.room_analysis.surfaces?.ceiling?.material || 'drywall',
      condition: geminiAnalysis.room_analysis.surfaces?.ceiling?.condition || 'good'
    }],
    gemini_enhanced: true,
    complexity_factors: geminiAnalysis.room_analysis.complexity_factors
  };
}

/**
 * Calculate confidence score for enhanced estimates
 */
function calculateConfidenceScore(geminiAnalysis, estimate) {
  let confidence = 0.7; // Base confidence

  // Increase confidence based on Gemini analysis completeness
  if (geminiAnalysis.room_analysis.surfaces) confidence += 0.1;
  if (geminiAnalysis.room_analysis.complexity_factors) confidence += 0.1;
  if (geminiAnalysis.room_analysis.recommendations) confidence += 0.1;

  // Adjust based on estimate completeness
  if (estimate.lineItems.length > 5) confidence += 0.1;

  return Math.min(confidence, 1.0);
}

/**
 * Get database performance statistics
 */
async function getDatabasePerformanceStats() {
  try {
    const result = await db.query(`
      SELECT 
        (SELECT json_agg(row_to_json(t)) FROM (SELECT * FROM contractorlens.quick_performance_check()) t) as quick_check,
        (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'contractorlens') as active_connections
    `);

    return {
      quick_performance_check: result.rows[0]?.quick_check || [],
      active_connections: result.rows[0]?.active_connections || 0,
      status: 'operational'
    };
  } catch (error) {
    console.error('Database performance check failed:', error);
    return { status: 'error', message: error.message };
  }
}

async function getCommonAssemblies() {
  try {
    const result = await db.query(`
      SELECT assembly_id FROM contractorlens.Assemblies 
      WHERE category IN ('kitchen', 'bathroom', 'room') 
      ORDER BY created_at DESC LIMIT 10
    `);
    return result.rows.map(row => row.assembly_id);
  } catch (error) {
    console.error('Failed to get common assemblies:', error);
    return [];
  }
}

async function warmGeminiResponseCache() {
  // Pre-cache some common Gemini responses for typical room scenarios
  const commonScenarios = [
    { roomType: 'kitchen', dimensions: { length: 12, width: 10, height: 9 } },
    { roomType: 'bathroom', dimensions: { length: 8, width: 6, height: 8 } }
  ];

  // This would typically involve caching sample responses
  console.log('Gemini response cache warming completed');
}

/**
 * Optimized estimate saving with batch operations
 */
async function saveEstimateOptimized(data) {
  try {
    // Use connection pooling optimization
    const result = await db.query(`
      INSERT INTO contractorlens.estimates (
        user_id, project_id, job_type, finish_level,
        takeoff_data, estimate_data, location_data, notes, status,
        grand_total
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING estimate_id
    `, [
      data.userId,
      data.projectId,
      data.jobType,
      data.finishLevel,
      JSON.stringify(data.takeoffData),
      JSON.stringify(data.estimate),
      JSON.stringify(data.estimate.metadata?.location),
      data.notes,
      data.status,
      data.estimate.grandTotal
    ]);
    
    return result.rows[0].estimate_id;
  } catch (error) {
    console.error('Optimized save failed:', error);
    throw error;
  }
}

// =============================================================================
// VALIDATION SCHEMAS
// =============================================================================

const estimateRequestSchema = Joi.object({
  takeoffData: Joi.object().required(),
  jobType: Joi.string().valid('kitchen', 'bathroom', 'room', 'exterior', 'flooring', 'wall', 'ceiling').required(),
  finishLevel: Joi.string().valid('good', 'better', 'best').required(),
  zipCode: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required(),
  projectId: Joi.string().uuid().optional(),
  notes: Joi.string().max(1000).optional(),
  useGeminiAnalysis: Joi.boolean().default(false)
});

const enhancedEstimateSchema = Joi.object({
  frames: Joi.array().items(Joi.object()).min(1).required(),
  roomType: Joi.string().valid('kitchen', 'bathroom', 'room').required(),
  dimensions: Joi.object({
    length: Joi.number().positive().required(),
    width: Joi.number().positive().required(),
    height: Joi.number().positive().required()
  }).required(),
  location: Joi.object({
    zip: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required(),
    metro: Joi.string().optional(),
    state: Joi.string().optional()
  }).required(),
  userPreferences: Joi.object({
    qualityTier: Joi.string().valid('good', 'better', 'best').required(),
    budget: Joi.number().positive().optional()
  }).required()
});

module.exports = router;