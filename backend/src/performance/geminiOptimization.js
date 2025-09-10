/**
 * Gemini Integration Performance Optimization
 * Performance Engineer: PERF001 - Phase 2 API Optimization
 * Target: <60s Gemini analysis with efficient frame processing
 * Created: 2025-09-05
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');
const sharp = require('sharp');

/**
 * Performance-optimized Gemini integration with:
 * - Intelligent frame sampling to reduce API calls
 * - Image compression and optimization
 * - Batch processing and parallel analysis
 * - Response caching for similar room conditions
 */
class OptimizedGeminiService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    
    // Performance configuration
    this.config = {
      maxFramesPerAnalysis: 5,        // Reduce API calls - 5 key frames vs all frames
      imageQuality: 80,               // Balance quality vs processing speed
      maxImageDimension: 1024,        // Optimize for Gemini processing
      batchSize: 3,                   // Process 3 frames in parallel max
      timeoutMs: 45000,               // 45 second timeout for Gemini calls
      retryAttempts: 2,               // Retry failed requests
      cacheResponsesMs: 300000        // Cache responses for 5 minutes
    };

    // Response cache for similar room analyses
    this.responseCache = new Map();
    this.performanceMetrics = {
      totalAnalyses: 0,
      averageProcessingTime: 0,
      cacheHits: 0,
      compressionRatio: 0,
      apiCallsReduced: 0
    };
  }

  /**
   * Main optimized analysis method
   * Processes AR frames efficiently for Assembly Engine integration
   */
  async analyzeRoom(frames, roomType, dimensions, analysisType = 'enhanced') {
    const startTime = Date.now();
    
    try {
      console.log(`🔍 Starting optimized Gemini analysis: ${frames.length} frames, ${roomType} room`);

      // Step 1: Check cache for similar analysis
      const cacheKey = this.generateCacheKey(frames, roomType, dimensions);
      const cachedResult = this.getCachedResponse(cacheKey);
      
      if (cachedResult) {
        console.log(`⚡ Cache hit: Returning cached Gemini analysis in ${Date.now() - startTime}ms`);
        this.performanceMetrics.cacheHits++;
        return cachedResult;
      }

      // Step 2: Intelligent frame selection (reduce API calls by 70-80%)
      const selectedFrames = await this.selectOptimalFrames(frames, roomType);
      console.log(`📸 Selected ${selectedFrames.length} optimal frames from ${frames.length} total`);

      // Step 3: Batch process frames with compression
      const processedFrames = await this.batchProcessFrames(selectedFrames);
      
      // Step 4: Generate optimized prompt based on analysis type
      const prompt = this.generateOptimizedPrompt(roomType, dimensions, analysisType);

      // Step 5: Call Gemini with optimized parameters
      const analysisResult = await this.callGeminiWithOptimization(processedFrames, prompt);

      // Step 6: Post-process and enhance results for Assembly Engine
      const enhancedResult = this.enhanceAnalysisForAssemblyEngine(
        analysisResult, roomType, dimensions
      );

      // Step 7: Cache successful results
      this.cacheResponse(cacheKey, enhancedResult);

      // Update performance metrics
      const processingTime = Date.now() - startTime;
      this.updatePerformanceMetrics(processingTime, frames.length, selectedFrames.length);

      console.log(`✅ Optimized Gemini analysis completed in ${processingTime}ms`);
      return enhancedResult;

    } catch (error) {
      console.error('❌ Optimized Gemini analysis failed:', error);
      
      // Fallback to basic analysis if enhanced fails
      if (analysisType === 'enhanced') {
        console.log('🔄 Falling back to basic analysis...');
        return await this.analyzeRoom(frames.slice(0, 2), roomType, dimensions, 'basic');
      }
      
      throw new Error(`Gemini analysis failed: ${error.message}`);
    }
  }

  /**
   * Intelligent frame selection to minimize API calls while maintaining quality
   */
  async selectOptimalFrames(frames, roomType) {
    if (frames.length <= this.config.maxFramesPerAnalysis) {
      return frames;
    }

    console.log(`🎯 Selecting optimal frames from ${frames.length} candidates`);

    // Frame selection strategy based on room type and visual diversity
    const selectedFrames = [];
    const frameStep = Math.floor(frames.length / this.config.maxFramesPerAnalysis);

    // Always include first and last frames (entry/exit perspective)
    selectedFrames.push(frames[0]);
    if (frames.length > 1) {
      selectedFrames.push(frames[frames.length - 1]);
    }

    // Select frames with maximum visual diversity
    for (let i = frameStep; i < frames.length - frameStep; i += frameStep) {
      if (selectedFrames.length < this.config.maxFramesPerAnalysis) {
        selectedFrames.push(frames[i]);
      }
    }

    // Ensure we have room-type specific coverage
    const roomSpecificFrame = this.selectRoomSpecificFrame(frames, roomType);
    if (roomSpecificFrame && selectedFrames.length < this.config.maxFramesPerAnalysis) {
      selectedFrames.push(roomSpecificFrame);
    }

    return selectedFrames.slice(0, this.config.maxFramesPerAnalysis);
  }

  /**
   * Select frame likely to show room-specific features
   */
  selectRoomSpecificFrame(frames, roomType) {
    // For now, select middle frame as most likely to show room center
    // In production, this could use ML to detect room-specific features
    const middleIndex = Math.floor(frames.length / 2);
    return frames[middleIndex];
  }

  /**
   * Batch process frames with compression and optimization
   */
  async batchProcessFrames(frames) {
    console.log(`🔧 Batch processing ${frames.length} frames`);

    const processingPromises = frames.map(async (frame, index) => {
      try {
        // Convert and compress frame
        const optimizedFrame = await this.optimizeFrameForGemini(frame);
        
        return {
          index,
          data: optimizedFrame,
          timestamp: frame.timestamp,
          frameType: this.classifyFrameType(frame)
        };
      } catch (error) {
        console.warn(`⚠️ Failed to process frame ${index}:`, error.message);
        return null;
      }
    });

    const processedFrames = await Promise.all(processingPromises);
    return processedFrames.filter(frame => frame !== null);
  }

  /**
   * Optimize frame for Gemini processing (compression, resizing)
   */
  async optimizeFrameForGemini(frame) {
    try {
      if (!frame.imageData) {
        throw new Error('No image data in frame');
      }

      // Convert base64 to buffer if needed
      let imageBuffer;
      if (typeof frame.imageData === 'string') {
        imageBuffer = Buffer.from(frame.imageData.replace(/^data:image\/[a-z]+;base64,/, ''), 'base64');
      } else {
        imageBuffer = frame.imageData;
      }

      // Optimize with Sharp
      const optimizedBuffer = await sharp(imageBuffer)
        .resize(this.config.maxImageDimension, this.config.maxImageDimension, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .jpeg({
          quality: this.config.imageQuality,
          progressive: true,
          mozjpeg: true
        })
        .toBuffer();

      // Calculate compression ratio for metrics
      const compressionRatio = optimizedBuffer.length / imageBuffer.length;
      this.performanceMetrics.compressionRatio = 
        (this.performanceMetrics.compressionRatio + compressionRatio) / 2;

      return optimizedBuffer.toString('base64');

    } catch (error) {
      console.error('Frame optimization failed:', error);
      return frame.imageData; // Return original if optimization fails
    }
  }

  /**
   * Classify frame type for targeted analysis
   */
  classifyFrameType(frame) {
    // Basic frame classification - in production this could use ML
    if (frame.timestamp) {
      const timestamp = new Date(frame.timestamp);
      const hour = timestamp.getHours();
      
      if (hour < 2) return 'overview';
      if (hour < 4) return 'detail';
      return 'closeup';
    }
    
    return 'general';
  }

  /**
   * Generate optimized prompt based on analysis requirements
   */
  generateOptimizedPrompt(roomType, dimensions, analysisType) {
    const basePrompt = `Analyze this ${roomType} room for construction estimation. Room dimensions: ${dimensions.length}' x ${dimensions.width}' x ${dimensions.height}'.`;

    if (analysisType === 'basic') {
      return `${basePrompt} Provide basic material identification and condition assessment in JSON format with: {"materials": {"flooring": "", "walls": "", "ceiling": ""}, "condition": "good/fair/poor", "complexity": 1.0-2.0}`;
    }

    // Enhanced analysis prompt
    return `${basePrompt}

ANALYSIS REQUIREMENTS:
1. Surface Materials: Identify flooring, wall, and ceiling materials
2. Condition Assessment: Rate condition (excellent/good/fair/poor) for each surface
3. Complexity Factors: Assess renovation complexity (1.0 = standard, 2.0 = very complex)
4. Cost Modifiers: Identify factors that would increase/decrease costs
5. Quality Recommendations: Suggest appropriate finish level (good/better/best)

Return JSON format:
{
  "surfaces": {
    "flooring": {"material": "", "condition": "", "area_sf": 0},
    "walls": {"material": "", "condition": "", "area_sf": 0},
    "ceiling": {"material": "", "condition": "", "area_sf": 0}
  },
  "complexity_factors": {
    "structural_changes": boolean,
    "accessibility": "easy/moderate/challenging",
    "existing_damage": boolean,
    "complexity_multiplier": 1.0-2.0
  },
  "cost_modifiers": {
    "condition_multiplier": 0.8-1.6,
    "complexity_multiplier": 1.0-2.0,
    "quality_recommendation": "good/better/best"
  },
  "recommendations": {
    "priority_items": ["item1", "item2"],
    "potential_issues": ["issue1", "issue2"],
    "estimated_timeline": "duration in days"
  }
}`;
  }

  /**
   * Call Gemini with optimization and retry logic
   */
  async callGeminiWithOptimization(processedFrames, prompt) {
    const maxRetries = this.config.retryAttempts;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        console.log(`🤖 Calling Gemini API (attempt ${attempt}/${maxRetries})`);

        // Prepare content for Gemini
        const content = [
          { text: prompt },
          ...processedFrames.map(frame => ({
            inlineData: {
              mimeType: "image/jpeg",
              data: frame.data
            }
          }))
        ];

        // Call Gemini with timeout
        const result = await Promise.race([
          this.model.generateContent(content),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Gemini API timeout')), this.config.timeoutMs)
          )
        ]);

        const response = await result.response;
        const text = response.text();

        // Parse JSON response
        try {
          return JSON.parse(text);
        } catch (parseError) {
          // If JSON parsing fails, extract JSON from text
          const jsonMatch = text.match(/\{[\s\S]*\}/);
          if (jsonMatch) {
            return JSON.parse(jsonMatch[0]);
          }
          throw new Error('Failed to parse JSON response');
        }

      } catch (error) {
        console.warn(`⚠️ Gemini API attempt ${attempt} failed:`, error.message);
        
        if (attempt === maxRetries) {
          throw error;
        }
        
        // Exponential backoff for retries
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
      }
    }
  }

  /**
   * Enhance Gemini results for Assembly Engine integration
   */
  enhanceAnalysisForAssemblyEngine(geminiResult, roomType, dimensions) {
    // Ensure compatibility with Assembly Engine expectations
    const enhanced = {
      room_analysis: {
        room_type: roomType,
        dimensions: dimensions,
        total_area: dimensions.length * dimensions.width,
        ...geminiResult
      },
      assembly_engine_enhancements: {
        takeoff_modifiers: this.generateTakeoffModifiers(geminiResult),
        cost_adjustments: this.generateCostAdjustments(geminiResult),
        quality_optimization: this.optimizeQualitySelection(geminiResult)
      },
      performance_metadata: {
        analysis_type: 'gemini_optimized',
        processing_optimizations: [
          'frame_selection_reduction',
          'image_compression',
          'batch_processing',
          'response_caching'
        ]
      }
    };

    return enhanced;
  }

  /**
   * Generate takeoff modifiers based on Gemini analysis
   */
  generateTakeoffModifiers(geminiResult) {
    const modifiers = {
      area_adjustment: 1.0,
      waste_factor: 1.05, // Default 5% waste
      accessibility_factor: 1.0
    };

    if (geminiResult.complexity_factors) {
      if (geminiResult.complexity_factors.accessibility === 'challenging') {
        modifiers.accessibility_factor = 1.15;
      } else if (geminiResult.complexity_factors.accessibility === 'moderate') {
        modifiers.accessibility_factor = 1.05;
      }

      if (geminiResult.complexity_factors.existing_damage) {
        modifiers.waste_factor = 1.15; // Increase waste factor for damaged areas
      }
    }

    return modifiers;
  }

  /**
   * Generate cost adjustments for Assembly Engine
   */
  generateCostAdjustments(geminiResult) {
    const adjustments = {
      material_condition_multiplier: 1.0,
      labor_complexity_multiplier: 1.0,
      overall_project_multiplier: 1.0
    };

    if (geminiResult.cost_modifiers) {
      adjustments.material_condition_multiplier = geminiResult.cost_modifiers.condition_multiplier || 1.0;
      adjustments.labor_complexity_multiplier = geminiResult.cost_modifiers.complexity_multiplier || 1.0;
    }

    // Calculate overall multiplier
    adjustments.overall_project_multiplier = 
      adjustments.material_condition_multiplier * adjustments.labor_complexity_multiplier;

    return adjustments;
  }

  /**
   * Optimize quality tier selection based on analysis
   */
  optimizeQualitySelection(geminiResult) {
    let recommendedTier = 'better'; // Default middle tier

    if (geminiResult.cost_modifiers?.quality_recommendation) {
      recommendedTier = geminiResult.cost_modifiers.quality_recommendation;
    }

    return {
      recommended_tier: recommendedTier,
      tier_justification: this.generateTierJustification(geminiResult, recommendedTier),
      alternative_options: this.generateAlternativeOptions(recommendedTier)
    };
  }

  generateTierJustification(geminiResult, tier) {
    const justifications = [];

    if (geminiResult.surfaces) {
      Object.entries(geminiResult.surfaces).forEach(([surface, data]) => {
        if (data.condition === 'excellent' && tier === 'best') {
          justifications.push(`${surface} in excellent condition supports premium finishes`);
        } else if (data.condition === 'poor' && tier === 'good') {
          justifications.push(`${surface} condition requires budget-focused approach`);
        }
      });
    }

    return justifications.length > 0 ? justifications : [`${tier} tier selected based on overall room assessment`];
  }

  generateAlternativeOptions(recommendedTier) {
    const tiers = ['good', 'better', 'best'];
    return tiers.filter(tier => tier !== recommendedTier);
  }

  // Cache management methods
  generateCacheKey(frames, roomType, dimensions) {
    const frameHashes = frames.slice(0, 3).map(frame => 
      require('crypto').createHash('md5').update(JSON.stringify(frame.timestamp)).digest('hex').substring(0, 8)
    );
    
    return `gemini_${roomType}_${dimensions.length}x${dimensions.width}_${frameHashes.join('_')}`;
  }

  getCachedResponse(cacheKey) {
    const cached = this.responseCache.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < this.config.cacheResponsesMs) {
      return cached.data;
    }
    
    if (cached) {
      this.responseCache.delete(cacheKey); // Remove expired cache
    }
    
    return null;
  }

  cacheResponse(cacheKey, data) {
    this.responseCache.set(cacheKey, {
      data,
      timestamp: Date.now()
    });

    // Clean up old cache entries
    if (this.responseCache.size > 50) {
      const oldestKey = this.responseCache.keys().next().value;
      this.responseCache.delete(oldestKey);
    }
  }

  // Performance monitoring
  updatePerformanceMetrics(processingTime, originalFrames, selectedFrames) {
    this.performanceMetrics.totalAnalyses++;
    this.performanceMetrics.averageProcessingTime = 
      (this.performanceMetrics.averageProcessingTime + processingTime) / 2;
    this.performanceMetrics.apiCallsReduced += (originalFrames - selectedFrames);
  }

  getPerformanceStats() {
    const cacheHitRate = this.performanceMetrics.totalAnalyses > 0 
      ? (this.performanceMetrics.cacheHits / this.performanceMetrics.totalAnalyses * 100).toFixed(2)
      : 0;

    return {
      gemini_optimization: {
        total_analyses: this.performanceMetrics.totalAnalyses,
        average_processing_time_ms: Math.round(this.performanceMetrics.averageProcessingTime),
        cache_hit_rate: `${cacheHitRate}%`,
        api_calls_reduced: this.performanceMetrics.apiCallsReduced,
        compression_ratio: (this.performanceMetrics.compressionRatio * 100).toFixed(1) + '%'
      },
      performance_targets: {
        gemini_analysis_time_ms: 60000,
        frame_reduction_ratio: '70%+',
        cache_hit_rate_target: '30%+',
        compression_savings: '60%+'
      },
      optimizations_active: [
        'intelligent_frame_selection',
        'image_compression_optimization', 
        'batch_processing',
        'response_caching',
        'retry_with_backoff'
      ]
    };
  }
}

module.exports = OptimizedGeminiService;