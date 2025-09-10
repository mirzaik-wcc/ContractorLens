const express = require('express');
const Joi = require('joi');
const { authenticate } = require('../middleware/auth');
const GeminiIntegrationService = require('../services/geminiIntegration');
const { firestore } = require('../config/firebase');

const router = express.Router();
const geminiIntegration = new GeminiIntegrationService();

// Input validation schemas
const enhancedScanDataSchema = Joi.object({
  scan_id: Joi.string().required(),
  room_type: Joi.string().valid('kitchen', 'bathroom', 'living_room', 'bedroom', 'dining_room', 'office', 'laundry_room').required(),
  
  // AR takeoff data
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

  // Room dimensions
  dimensions: Joi.object({
    length: Joi.number().positive().required(),
    width: Joi.number().positive().required(),
    height: Joi.number().positive().required(),
    total_area: Joi.number().positive().required()
  }).required(),

  // Image frames for analysis
  frames: Joi.array().items(
    Joi.object({
      timestamp: Joi.string().required(),
      imageData: Joi.string().required(), // Base64 encoded
      mimeType: Joi.string().default('image/jpeg'),
      cameraPosition: Joi.object().optional(),
      lighting_conditions: Joi.string().valid('excellent', 'good', 'fair', 'poor').optional()
    })
  ).min(1).max(20).required(),

  surfaces_detected: Joi.array().items(
    Joi.object({
      type: Joi.string().valid('floor', 'wall', 'ceiling').required(),
      area: Joi.number().positive().required()
    })
  ).optional(),

  start_time: Joi.number().optional()
});

const enhancedEstimateRequestSchema = Joi.object({
  enhancedScanData: enhancedScanDataSchema.required(),
  finishLevel: Joi.string().valid('good', 'better', 'best').required(),
  zipCode: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required(),
  projectId: Joi.string().uuid().optional(),
  notes: Joi.string().max(1000).optional(),
  fallbackToBasic: Joi.boolean().default(true) // Fall back to basic estimate if Gemini fails
});

/**
 * GET /api/v1/analysis/health
 * Health check for Gemini integration service
 */
router.get('/api/v1/analysis/health', async (req, res) => {
  try {
    const health = await geminiIntegration.healthCheck();
    
    const statusCode = health.status === 'healthy' ? 200 : 
                      health.status === 'degraded' ? 200 : 503;
    
    res.status(statusCode).json(health);
  } catch (error) {
    console.error('Analysis health check failed:', error);
    res.status(503).json({
      service: 'gemini-integration',
      status: 'unhealthy',
      error: error.message
    });
  }
});

/**
 * POST /api/v1/analysis/enhanced-estimate
 * Create enhanced estimate using AR scan + Gemini analysis + Assembly Engine
 * 
 * This is the premium workflow:
 * AR scan → Gemini material/condition analysis → Assembly Engine calculation
 */
router.post('/api/v1/analysis/enhanced-estimate', authenticate, async (req, res) => {
  try {
    console.log(`Enhanced estimate request from user ${req.user.uid}`);

    // Validate request body
    const { error, value } = enhancedEstimateRequestSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Invalid request data',
        details: error.details,
        code: 'VALIDATION_FAILED'
      });
    }
    
    const { enhancedScanData, finishLevel, zipCode, projectId, notes, fallbackToBasic } = value;

    // Get user settings from Firestore
    let userSettings;
    try {
      const userDoc = await firestore.collection('userSettings').doc(req.user.uid).get();
      
      if (userDoc.exists) {
        userSettings = userDoc.data();
      } else {
        // Default settings
        userSettings = {
          hourly_rate: 50,
          markup_percentage: 25,
          tax_rate: 0.08,
          preferred_quality_tier: finishLevel
        };
        await firestore.collection('userSettings').doc(req.user.uid).set(userSettings);
      }
    } catch (firestoreError) {
      console.error('Firestore error, using defaults:', firestoreError);
      userSettings = {
        hourly_rate: 50,
        markup_percentage: 25,
        tax_rate: 0.08
      };
    }

    let estimate;
    let analysisMethod = 'enhanced';

    try {
      // Attempt enhanced estimate with Gemini analysis
      console.log('Creating enhanced estimate with Gemini analysis...');
      estimate = await geminiIntegration.createEnhancedEstimate(
        enhancedScanData,
        finishLevel,
        zipCode,
        userSettings
      );

    } catch (geminiError) {
      console.error('Gemini enhanced estimate failed:', geminiError);

      if (!fallbackToBasic) {
        return res.status(422).json({
          error: 'Enhanced analysis failed and fallback disabled',
          details: geminiError.message,
          code: 'ANALYSIS_FAILED'
        });
      }

      // Fallback to basic Assembly Engine estimate
      console.log('Falling back to basic Assembly Engine estimate...');
      analysisMethod = 'fallback';
      
      estimate = await geminiIntegration.createFallbackEstimate(
        enhancedScanData.takeoff_data,
        enhancedScanData.room_type,
        finishLevel,
        zipCode,
        userSettings
      );

      // Add fallback metadata
      estimate.metadata = {
        ...estimate.metadata,
        analysis_method: 'fallback',
        ai_enhanced: false,
        fallback_reason: geminiError.message
      };
    }

    // Save enhanced estimate to database
    const estimateId = await saveEnhancedEstimate({
      userId: req.user.uid,
      projectId: projectId || null,
      enhancedScanData,
      finishLevel,
      zipCode,
      estimate,
      notes,
      analysisMethod,
      status: 'draft'
    });

    // Response includes the full enhanced estimate
    res.status(201).json({
      estimateId,
      status: 'draft',
      analysisMethod,
      createdAt: new Date().toISOString(),
      ...estimate
    });

  } catch (error) {
    console.error('Enhanced estimate creation error:', error);
    
    if (error.message.includes('Invalid')) {
      return res.status(400).json({ 
        error: error.message,
        code: 'VALIDATION_FAILED'
      });
    }
    
    res.status(500).json({ 
      error: 'Failed to create enhanced estimate',
      code: 'INTERNAL_ERROR'
    });
  }
});

/**
 * POST /api/v1/analysis/room-analysis
 * Analyze room images without creating estimate (for preview/validation)
 */
router.post('/api/v1/analysis/room-analysis', authenticate, async (req, res) => {
  try {
    // Validate scan data (without takeoff_data requirement)
    const roomAnalysisSchema = Joi.object({
      scan_id: Joi.string().required(),
      room_type: Joi.string().valid('kitchen', 'bathroom', 'living_room', 'bedroom', 'dining_room', 'office', 'laundry_room').required(),
      dimensions: Joi.object({
        length: Joi.number().positive().required(),
        width: Joi.number().positive().required(),
        height: Joi.number().positive().required(),
        total_area: Joi.number().positive().required()
      }).required(),
      frames: Joi.array().items(
        Joi.object({
          timestamp: Joi.string().required(),
          imageData: Joi.string().required(),
          mimeType: Joi.string().default('image/jpeg'),
          cameraPosition: Joi.object().optional(),
          lighting_conditions: Joi.string().optional()
        })
      ).min(1).max(20).required(),
      surfaces_detected: Joi.array().optional(),
      start_time: Joi.number().optional()
    });

    const { error, value } = roomAnalysisSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Invalid scan data',
        details: error.details,
        code: 'VALIDATION_FAILED'
      });
    }

    console.log(`Room analysis request for ${value.room_type} from user ${req.user.uid}`);

    // Initialize Gemini service
    await geminiIntegration.initialize();

    // Run Gemini analysis
    const analysis = await geminiIntegration.geminiSurveyor.analyzeScan(value);

    // Return just the analysis without estimate calculation
    res.json({
      scan_id: value.scan_id,
      analysis_completed: true,
      room_analysis: analysis,
      analyzed_at: new Date().toISOString()
    });

  } catch (error) {
    console.error('Room analysis error:', error);
    
    if (error.message.includes('Invalid')) {
      return res.status(400).json({ 
        error: error.message,
        code: 'ANALYSIS_FAILED'
      });
    }
    
    res.status(500).json({ 
      error: 'Failed to analyze room',
      code: 'INTERNAL_ERROR'
    });
  }
});

/**
 * GET /api/v1/analysis/capabilities
 * Return service capabilities and supported room types
 */
router.get('/api/v1/analysis/capabilities', (req, res) => {
  res.json({
    service: 'ContractorLens Gemini Integration',
    version: '1.0.0',
    capabilities: {
      room_analysis: true,
      material_identification: true,
      condition_assessment: true,
      assembly_recommendations: true,
      enhanced_estimates: true,
      fallback_estimates: true
    },
    supported_room_types: [
      'kitchen',
      'bathroom',
      'living_room',
      'bedroom',
      'dining_room',
      'office',
      'laundry_room'
    ],
    supported_finish_levels: ['good', 'better', 'best'],
    max_frames_per_scan: 20,
    supported_image_formats: ['image/jpeg', 'image/png'],
    gemini_model: process.env.GEMINI_MODEL || 'gemini-1.5-pro'
  });
});

/**
 * Helper function to save enhanced estimate to database
 */
async function saveEnhancedEstimate(data) {
  const db = require('../config/database');
  
  const {
    userId, projectId, enhancedScanData, finishLevel, zipCode,
    estimate, notes, analysisMethod, status
  } = data;

  // Ensure enhanced_estimates table exists
  await ensureEnhancedEstimatesTable(db);
  
  const result = await db.query(`
    INSERT INTO contractorlens.enhanced_estimates (
      user_id, project_id, scan_id, room_type, finish_level,
      enhanced_scan_data, estimate_data, analysis_method, notes, status,
      grand_total, ai_enhanced
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    RETURNING estimate_id
  `, [
    userId,
    projectId,
    enhancedScanData.scan_id,
    enhancedScanData.room_type,
    finishLevel,
    JSON.stringify(enhancedScanData),
    JSON.stringify(estimate),
    analysisMethod,
    notes,
    status,
    estimate.grandTotal,
    estimate.metadata?.ai_enhanced || false
  ]);

  return result.rows[0].estimate_id;
}

/**
 * Ensure enhanced estimates table exists
 */
async function ensureEnhancedEstimatesTable(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS contractorlens.enhanced_estimates (
      estimate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id VARCHAR(255) NOT NULL,
      project_id UUID REFERENCES contractorlens.Projects(project_id) ON DELETE SET NULL,
      
      -- Scan identification
      scan_id VARCHAR(255) NOT NULL,
      room_type VARCHAR(50) NOT NULL,
      finish_level VARCHAR(20) NOT NULL CHECK (finish_level IN ('good', 'better', 'best')),
      
      -- Enhanced data storage
      enhanced_scan_data JSONB NOT NULL,
      estimate_data JSONB NOT NULL,
      
      -- Analysis tracking
      analysis_method VARCHAR(20) DEFAULT 'enhanced' CHECK (analysis_method IN ('enhanced', 'fallback')),
      ai_enhanced BOOLEAN DEFAULT true,
      
      -- Quick access fields
      grand_total DECIMAL(10,2),
      
      -- Metadata
      notes TEXT,
      status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'invoiced', 'archived')),
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )
  `);

  // Create indexes
  await db.query(`
    CREATE INDEX IF NOT EXISTS idx_enhanced_estimates_user_id ON contractorlens.enhanced_estimates(user_id);
    CREATE INDEX IF NOT EXISTS idx_enhanced_estimates_scan_id ON contractorlens.enhanced_estimates(scan_id);
    CREATE INDEX IF NOT EXISTS idx_enhanced_estimates_room_type ON contractorlens.enhanced_estimates(room_type);
    CREATE INDEX IF NOT EXISTS idx_enhanced_estimates_ai_enhanced ON contractorlens.enhanced_estimates(ai_enhanced);
    CREATE INDEX IF NOT EXISTS idx_enhanced_estimates_created_at ON contractorlens.enhanced_estimates(created_at);
  `);
}

module.exports = router;