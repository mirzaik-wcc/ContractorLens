# ContractorLens Gemini Digital Surveyor Service

The ML Engineer agent's implementation of Gemini as a digital surveyor for material identification and condition assessment in ContractorLens.

## Overview

This service analyzes AR scan frames and room measurements to identify materials, assess conditions, and recommend quality tiers. **It does NOT calculate costs** - it serves as the "digital eyes" of an experienced contractor, feeding structured insights to the Assembly Engine for deterministic cost calculations.

## Architecture

```
gemini-service/
├── analyzer.js                 # Main service entry point
├── package.json               # Dependencies and scripts
├── .env.example              # Environment configuration template
├── prompts/                  # Specialized analysis prompts
│   ├── surveyor-prompt.md    # Master surveyor prompt
│   ├── kitchen-prompt.md     # Kitchen-specific analysis
│   └── bathroom-prompt.md    # Bathroom-specific analysis
├── preprocessing/            # AR data processing utilities
│   ├── frameProcessor.js     # Frame optimization and compression
│   └── measurementEnricher.js # Measurement analysis and validation
└── tests/                   # Comprehensive test suite
    └── analyzer.test.js     # Unit and integration tests
```

## Core Capabilities

### 🔍 Digital Surveyor Analysis
- **Material Identification**: Recognizes flooring, wall, ceiling materials with precision
- **Condition Assessment**: Evaluates current state using standardized scale (excellent/good/fair/poor)
- **Quality Tier Recommendations**: Maps existing conditions to appropriate good/better/best upgrades
- **Complexity Assessment**: Identifies installation challenges and special requirements

### 🖼️ Multimodal Processing
- **AR Frame Analysis**: Processes multiple camera frames from iOS scanning
- **Measurement Integration**: Validates visual analysis against 3D measurements
- **Context Enhancement**: Adds temporal and spatial context to frame analysis
- **Quality Optimization**: Selects best frames and optimizes for Gemini processing

### 📊 Structured Output
- **Assembly Engine Ready**: JSON format designed for downstream cost calculations
- **Validation & Fallbacks**: Robust error handling ensures reliable operation
- **Metadata Tracking**: Processing statistics and quality metrics

## Installation

```bash
cd ml-services/gemini-service
npm install
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
# Required
GEMINI_API_KEY=your_gemini_api_key_here

# Optional
GEMINI_MODEL=gemini-1.5-pro
MAX_FRAMES_PER_SCAN=10
FRAME_QUALITY_THRESHOLD=0.6
```

## Usage

### Basic Usage

```javascript
const GeminiDigitalSurveyor = require('./analyzer');

const surveyor = new GeminiDigitalSurveyor();

const scanData = {
  scan_id: 'kitchen-scan-001',
  room_type: 'kitchen',
  dimensions: {
    length: 12.5,
    width: 10.0,
    height: 8.5,
    total_area: 125.0
  },
  frames: [
    {
      timestamp: '2024-01-15T14:30:00Z',
      imageData: 'base64_encoded_jpeg',
      lighting_conditions: 'good'
    }
    // ... more frames
  ]
};

const analysis = await surveyor.analyzeScan(scanData);
console.log('Material Analysis:', analysis);
```

### Expected Input Format

```javascript
{
  scan_id: "unique-scan-identifier",
  room_type: "kitchen|bathroom|living_room|bedroom|dining_room|office|laundry_room",
  dimensions: {
    length: 12.5,        // feet
    width: 10.0,         // feet  
    height: 8.5,         // feet
    total_area: 125.0    // square feet
  },
  frames: [
    {
      timestamp: "2024-01-15T14:30:00Z",
      imageData: "base64_encoded_image",
      mimeType: "image/jpeg",
      lighting_conditions: "excellent|good|fair|poor"
    }
  ],
  surfaces_detected: [    // Optional
    { type: "floor", area: 125.0 },
    { type: "wall", area: 320.0 }
  ]
}
```

### Output Format

```javascript
{
  room_type: "kitchen",
  dimensions_validated: {
    length_ft: 12.5,
    width_ft: 10.0,
    height_ft: 8.5,
    notes: "Measurements validation notes"
  },
  surfaces: {
    flooring: {
      current_material: "ceramic_tile",
      condition: "fair",
      removal_required: true,
      subfloor_condition: "good",
      recommendations: {
        good: "vinyl_plank",
        better: "porcelain_tile",
        best: "natural_stone"
      }
    },
    walls: {
      primary_material: "drywall",
      condition: "good",
      repair_needed: ["minor_holes"],
      special_considerations: []
    },
    ceiling: {
      material: "drywall", 
      condition: "good",
      height_standard: true
    }
  },
  complexity_factors: {
    accessibility: "standard",
    utilities_present: ["electrical", "plumbing"],
    structural_considerations: [],
    moisture_concerns: false,
    ventilation_adequate: true
  },
  assembly_recommendations: {
    suggested_assemblies: ["kitchen_standard"],
    customization_needed: [],
    quality_tier_rationale: "Good existing conditions support standard renovation"
  },
  metadata: {
    scan_id: "kitchen-scan-001",
    analyzed_at: "2024-01-15T22:30:00Z",
    model_version: "gemini-1.5-pro",
    frame_count: 8,
    processing_time_ms: 3240
  }
}
```

## Testing

Run the comprehensive test suite:

```bash
npm test
```

Test coverage includes:
- Input validation
- Prompt construction
- Response parsing with fallbacks
- Frame processing utilities
- Measurement enrichment
- Integration scenarios

## Integration Points

### Input from iOS App
- Receives AR scan data with frames and measurements
- Validates data structure and content
- Preprocesses frames for optimal analysis

### Output to Assembly Engine  
- Provides material classifications and quality assessments
- Includes complexity factors for installation planning
- **Does not include cost calculations** - maintains strict separation

### Parallel with Database Development
- Independent of specific database schema
- Works with any storage backend through JSON interface
- No database dependencies for core functionality

## Prompt Engineering

The service uses specialized prompts that:
- **Prohibit cost estimation** - Multiple safeguards prevent cost-related outputs
- **Focus on material identification** - Detailed classification standards
- **Assess conditions objectively** - Standardized condition scales
- **Recommend quality tiers** - Based on existing infrastructure capacity
- **Room-specific guidance** - Specialized prompts for kitchens, bathrooms

## Error Handling & Reliability

- **Input Validation**: Joi schema validation prevents invalid data processing
- **Fallback Analysis**: If Gemini response fails parsing, returns structured fallback
- **Quality Filtering**: Processes only high-quality frames for better results
- **Graceful Degradation**: System continues operation even with partial failures

## Performance Considerations

- **Frame Optimization**: Selects optimal frames, compresses images
- **Caching**: Prompt caching reduces initialization overhead  
- **Batch Processing**: Efficient multimodal requests to Gemini
- **Quality Thresholds**: Configurable quality filtering

## Production Deployment

### Environment Variables
```bash
GEMINI_API_KEY=production_api_key
NODE_ENV=production
MAX_FRAMES_PER_SCAN=8
FRAME_QUALITY_THRESHOLD=0.7
```

### Monitoring
- Processing statistics available via `getProcessingStats()`
- Metadata tracking for performance analysis
- Error logging for debugging

### Scaling
- Stateless service design enables horizontal scaling
- No persistent state between requests
- Configurable resource limits

## Development Workflow

1. **Setup**: Copy `.env.example`, install dependencies
2. **Development**: Modify prompts or processing logic
3. **Testing**: Run test suite, validate with sample data
4. **Integration**: Test with iOS AR data
5. **Production**: Deploy with production configuration

## Critical Success Factors

✅ **Material Classification Accuracy**: Detailed prompts ensure precise identification  
✅ **Structured Output Consistency**: Joi validation and fallback mechanisms  
✅ **Integration Readiness**: Standard JSON format with comprehensive error handling  
✅ **Cost Calculation Separation**: Strict prohibition of cost-related outputs  
✅ **Scalable Architecture**: Modular design supports additional room types  

## Support

For issues or questions:
1. Check the test suite for usage examples
2. Review prompt files for output format specifications  
3. Validate input data format against schema
4. Check environment variable configuration

---

**Remember**: This service is a digital surveyor, not a cost estimator. It identifies what exists and assesses conditions - the Assembly Engine handles all cost calculations deterministically.