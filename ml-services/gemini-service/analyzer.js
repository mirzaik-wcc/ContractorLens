const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs').promises;
const path = require('path');
const Joi = require('joi');

class GeminiDigitalSurveyor {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    this.model = this.genAI.getGenerativeModel({ 
      model: process.env.GEMINI_MODEL || 'gemini-1.5-pro'
    });
    
    this.promptCache = new Map();
    this.initialized = false;
  }

  async initialize() {
    if (this.initialized) return;
    
    // Validate API key
    if (!process.env.GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY environment variable is required');
    }
    
    // Load and cache prompts
    await this.loadPrompts();
    this.initialized = true;
  }

  async loadPrompts() {
    const promptsDir = path.join(__dirname, 'prompts');
    
    try {
      const surveyorPrompt = await fs.readFile(
        path.join(promptsDir, 'surveyor-prompt.md'), 
        'utf-8'
      );
      this.promptCache.set('surveyor', surveyorPrompt);

      const kitchenPrompt = await fs.readFile(
        path.join(promptsDir, 'kitchen-prompt.md'), 
        'utf-8'
      );
      this.promptCache.set('kitchen', kitchenPrompt);

      const bathroomPrompt = await fs.readFile(
        path.join(promptsDir, 'bathroom-prompt.md'), 
        'utf-8'
      );
      this.promptCache.set('bathroom', bathroomPrompt);
    } catch (error) {
      console.warn('Some prompt files not found, using default prompt');
    }
  }

  async analyzeScan(scanData) {
    await this.initialize();
    
    // Validate input data
    const validation = this.validateScanData(scanData);
    if (validation.error) {
      throw new Error(`Invalid scan data: ${validation.error.message}`);
    }

    try {
      // Build the surveyor prompt with context
      const analysisPrompt = await this.buildSurveyorPrompt(scanData);
      
      // Prepare multimodal content
      const content = [
        { text: analysisPrompt },
        ...scanData.frames.map(frame => ({
          inlineData: {
            data: frame.imageData,
            mimeType: frame.mimeType || 'image/jpeg'
          }
        }))
      ];

      // Generate analysis with Gemini
      const result = await this.model.generateContent(content);
      const responseText = result.response.text();
      
      // Parse and validate the response
      const analysis = this.parseAnalysisResult(responseText, scanData);
      
      // Add metadata
      analysis.metadata = {
        scan_id: scanData.scan_id,
        analyzed_at: new Date().toISOString(),
        model_version: process.env.GEMINI_MODEL || 'gemini-1.5-pro',
        frame_count: scanData.frames.length,
        processing_time_ms: Date.now() - (scanData.start_time || Date.now())
      };

      return analysis;
    } catch (error) {
      console.error('Gemini analysis error:', error);
      throw new Error(`Failed to analyze room scan: ${error.message}`);
    }
  }

  validateScanData(scanData) {
    const schema = Joi.object({
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
          timestamp: Joi.string().isoDate().required(),
          imageData: Joi.string().required(),
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

    return schema.validate(scanData);
  }

  async buildSurveyorPrompt(scanData) {
    const basePrompt = this.promptCache.get('surveyor') || this.getDefaultSurveyorPrompt();
    const roomSpecificPrompt = this.promptCache.get(scanData.room_type) || '';

    // Template replacement
    let prompt = basePrompt
      .replace('{room_type}', scanData.room_type)
      .replace('{length}', scanData.dimensions.length)
      .replace('{width}', scanData.dimensions.width)
      .replace('{height}', scanData.dimensions.height)
      .replace('{total_area}', scanData.dimensions.total_area);

    // Add room-specific guidance
    if (roomSpecificPrompt) {
      prompt += '\n\n## Room-Specific Analysis\n' + roomSpecificPrompt;
    }

    // Add surface context if available
    if (scanData.surfaces_detected && scanData.surfaces_detected.length > 0) {
      prompt += '\n\n## Detected Surfaces Context\n';
      scanData.surfaces_detected.forEach(surface => {
        prompt += `- ${surface.type}: ${surface.area} sq ft\n`;
      });
    }

    // Add frame context
    prompt += `\n\n## Analysis Context\n`;
    prompt += `- Total frames: ${scanData.frames.length}\n`;
    prompt += `- Frame timestamps span: ${scanData.frames[0]?.timestamp} to ${scanData.frames[scanData.frames.length - 1]?.timestamp}\n`;
    
    if (scanData.frames.some(f => f.lighting_conditions)) {
      const lightingConditions = [...new Set(scanData.frames.map(f => f.lighting_conditions).filter(Boolean))];
      prompt += `- Lighting conditions observed: ${lightingConditions.join(', ')}\n`;
    }

    return prompt;
  }

  parseAnalysisResult(rawText, originalScanData) {
    try {
      // Clean the response text
      let cleanedText = rawText.trim();
      
      // Remove markdown code blocks if present
      cleanedText = cleanedText.replace(/```json\n?/g, '').replace(/```\n?/g, '');
      
      // Parse JSON
      const analysis = JSON.parse(cleanedText);
      
      // Validate the structure
      const validation = this.validateAnalysisResult(analysis);
      if (validation.error) {
        console.warn('Analysis result validation failed:', validation.error.message);
        // Return a fallback structure with available data
        return this.createFallbackAnalysis(originalScanData, cleanedText);
      }
      
      return analysis;
    } catch (parseError) {
      console.error('Failed to parse Gemini response as JSON:', parseError);
      console.error('Raw response:', rawText);
      
      // Return fallback analysis
      return this.createFallbackAnalysis(originalScanData, rawText);
    }
  }

  validateAnalysisResult(analysis) {
    const schema = Joi.object({
      room_type: Joi.string().required(),
      dimensions_validated: Joi.object({
        length_ft: Joi.number().required(),
        width_ft: Joi.number().required(),
        height_ft: Joi.number().required(),
        notes: Joi.string().optional()
      }).required(),
      surfaces: Joi.object({
        flooring: Joi.object({
          current_material: Joi.string().required(),
          condition: Joi.string().valid('excellent', 'good', 'fair', 'poor').required(),
          removal_required: Joi.boolean().required(),
          subfloor_condition: Joi.string().valid('good', 'needs_repair', 'unknown').required(),
          recommendations: Joi.object({
            good: Joi.string().required(),
            better: Joi.string().required(),
            best: Joi.string().required()
          }).required()
        }).required(),
        walls: Joi.object({
          primary_material: Joi.string().required(),
          condition: Joi.string().valid('excellent', 'good', 'fair', 'poor').required(),
          repair_needed: Joi.array().items(Joi.string()).required(),
          special_considerations: Joi.array().items(Joi.string()).optional()
        }).required(),
        ceiling: Joi.object({
          material: Joi.string().required(),
          condition: Joi.string().valid('excellent', 'good', 'fair', 'poor').required(),
          height_standard: Joi.boolean().required()
        }).required()
      }).required(),
      complexity_factors: Joi.object({
        accessibility: Joi.string().valid('standard', 'challenging', 'very_difficult').required(),
        utilities_present: Joi.array().items(Joi.string()).required(),
        structural_considerations: Joi.array().items(Joi.string()).optional(),
        moisture_concerns: Joi.boolean().required(),
        ventilation_adequate: Joi.boolean().required()
      }).required(),
      assembly_recommendations: Joi.object({
        suggested_assemblies: Joi.array().items(Joi.string()).required(),
        customization_needed: Joi.array().items(Joi.string()).optional(),
        quality_tier_rationale: Joi.string().required()
      }).required()
    });

    return schema.validate(analysis);
  }

  createFallbackAnalysis(scanData, rawResponse) {
    return {
      room_type: scanData.room_type,
      dimensions_validated: {
        length_ft: scanData.dimensions.length,
        width_ft: scanData.dimensions.width,
        height_ft: scanData.dimensions.height,
        notes: "Fallback analysis - original response could not be parsed"
      },
      surfaces: {
        flooring: {
          current_material: "unknown",
          condition: "unknown",
          removal_required: true,
          subfloor_condition: "unknown",
          recommendations: {
            good: "vinyl_plank",
            better: "ceramic_tile",
            best: "hardwood"
          }
        },
        walls: {
          primary_material: "drywall",
          condition: "unknown",
          repair_needed: [],
          special_considerations: []
        },
        ceiling: {
          material: "drywall",
          condition: "unknown",
          height_standard: true
        }
      },
      complexity_factors: {
        accessibility: "standard",
        utilities_present: [],
        structural_considerations: [],
        moisture_concerns: false,
        ventilation_adequate: true
      },
      assembly_recommendations: {
        suggested_assemblies: [`${scanData.room_type}_standard`],
        customization_needed: [],
        quality_tier_rationale: "Fallback analysis - requires manual review"
      },
      fallback_info: {
        raw_response: rawResponse,
        error: "Could not parse Gemini response into expected JSON format"
      }
    };
  }

  getDefaultSurveyorPrompt() {
    return `You are an experienced contractor surveying a {room_type} for renovation. Analyze the provided images and measurements to identify materials, conditions, and installation considerations.

## Your Role
- **Material Identifier**: Recognize flooring, wall, ceiling materials
- **Condition Assessor**: Evaluate current state and preparation needs  
- **Quality Advisor**: Recommend good/better/best tier options
- **Complexity Evaluator**: Identify factors affecting installation difficulty

## CRITICAL: You Do NOT Estimate Costs
- Never provide dollar amounts or cost estimates
- Focus only on material identification and quality assessment
- Cost calculations happen elsewhere in the system

## Room Measurements Context
Room dimensions: {length}ft x {width}ft x {height}ft (Total: {total_area} sq ft)

## Analysis Format
Return ONLY a JSON object with this exact structure:

{
  "room_type": "{room_type}",
  "dimensions_validated": {
    "length_ft": {length},
    "width_ft": {width},
    "height_ft": {height},
    "notes": "Measurements appear accurate based on visual analysis"
  },
  "surfaces": {
    "flooring": {
      "current_material": "ceramic_tile|hardwood|carpet|vinyl|concrete|laminate|tile",
      "condition": "excellent|good|fair|poor",
      "removal_required": true,
      "subfloor_condition": "good|needs_repair|unknown",
      "recommendations": {
        "good": "vinyl_plank",
        "better": "ceramic_tile", 
        "best": "natural_stone"
      }
    },
    "walls": {
      "primary_material": "drywall|plaster|tile|paneling|brick",
      "condition": "excellent|good|fair|poor",
      "repair_needed": ["holes", "cracks", "water_damage"],
      "special_considerations": ["moisture_barrier_needed", "electrical_work"]
    },
    "ceiling": {
      "material": "drywall|drop_ceiling|exposed_beam|plaster",
      "condition": "excellent|good|fair|poor",
      "height_standard": true
    }
  },
  "complexity_factors": {
    "accessibility": "standard|challenging|very_difficult",
    "utilities_present": ["electrical", "plumbing", "hvac"],
    "structural_considerations": ["load_bearing_wall", "uneven_floors"],
    "moisture_concerns": true,
    "ventilation_adequate": true
  },
  "assembly_recommendations": {
    "suggested_assemblies": ["{room_type}_standard", "{room_type}_premium"],
    "customization_needed": ["custom_countertops", "electrical_upgrade"],
    "quality_tier_rationale": "Existing infrastructure supports better tier materials"
  }
}

Respond ONLY with the JSON object. No additional text or explanation.`;
  }

  // Utility method to get processing statistics
  getProcessingStats() {
    return {
      prompts_loaded: this.promptCache.size,
      initialized: this.initialized,
      model: process.env.GEMINI_MODEL || 'gemini-1.5-pro'
    };
  }
}

module.exports = GeminiDigitalSurveyor;

// Export for direct CLI usage
if (require.main === module) {
  console.log('ContractorLens Gemini Digital Surveyor Service');
  console.log('============================================');
  
  const surveyor = new GeminiDigitalSurveyor();
  console.log('Service initialized. Processing stats:', surveyor.getProcessingStats());
  
  // Example usage
  console.log('\nTo use this service:');
  console.log('const surveyor = new GeminiDigitalSurveyor();');
  console.log('const analysis = await surveyor.analyzeScan(scanData);');
}