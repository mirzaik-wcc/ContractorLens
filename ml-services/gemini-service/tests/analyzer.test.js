const GeminiDigitalSurveyor = require('../analyzer');
const ARFrameProcessor = require('../preprocessing/frameProcessor');
const MeasurementEnricher = require('../preprocessing/measurementEnricher');

// Mock Gemini API for testing
jest.mock('@google/generative-ai');

describe('GeminiDigitalSurveyor', () => {
  let surveyor;
  let mockScanData;

  beforeEach(() => {
    // Setup environment variables
    process.env.GEMINI_API_KEY = 'test-api-key';
    process.env.GEMINI_MODEL = 'gemini-1.5-pro';

    surveyor = new GeminiDigitalSurveyor();

    // Create comprehensive mock scan data
    mockScanData = {
      scan_id: 'test-scan-001',
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
          imageData: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==', // 1x1 red pixel
          mimeType: 'image/jpeg',
          lighting_conditions: 'good'
        },
        {
          timestamp: '2024-01-15T14:30:05Z',
          imageData: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', // 1x1 blue pixel
          mimeType: 'image/jpeg',
          lighting_conditions: 'excellent'
        }
      ],
      surfaces_detected: [
        { type: 'floor', area: 125.0 },
        { type: 'wall', area: 320.0 },
        { type: 'ceiling', area: 125.0 }
      ],
      start_time: Date.now()
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Input Validation', () => {
    test('should validate scan data structure', () => {
      const invalidData = { invalid: 'data' };
      
      return expect(surveyor.analyzeScan(invalidData))
        .rejects
        .toThrow('Invalid scan data');
    });

    test('should require scan_id', () => {
      const dataWithoutId = { ...mockScanData };
      delete dataWithoutId.scan_id;
      
      return expect(surveyor.analyzeScan(dataWithoutId))
        .rejects
        .toThrow('Invalid scan data');
    });

    test('should validate room_type enum', () => {
      const invalidRoomType = {
        ...mockScanData,
        room_type: 'invalid_room'
      };
      
      return expect(surveyor.analyzeScan(invalidRoomType))
        .rejects
        .toThrow('Invalid scan data');
    });

    test('should require positive dimensions', () => {
      const negativeDimensions = {
        ...mockScanData,
        dimensions: {
          ...mockScanData.dimensions,
          length: -5
        }
      };
      
      return expect(surveyor.analyzeScan(negativeDimensions))
        .rejects
        .toThrow('Invalid scan data');
    });
  });

  describe('Prompt Building', () => {
    beforeEach(async () => {
      await surveyor.initialize();
    });

    test('should build surveyor prompt with measurements', async () => {
      const prompt = await surveyor.buildSurveyorPrompt(mockScanData);
      
      expect(prompt).toContain('kitchen');
      expect(prompt).toContain('12.5ft x 10.0ft x 8.5ft');
      expect(prompt).toContain('125.0 sq ft');
    });

    test('should include surface context when available', async () => {
      const prompt = await surveyor.buildSurveyorPrompt(mockScanData);
      
      expect(prompt).toContain('floor: 125 sq ft');
      expect(prompt).toContain('wall: 320 sq ft');
    });

    test('should handle missing surfaces gracefully', async () => {
      const dataWithoutSurfaces = { ...mockScanData };
      delete dataWithoutSurfaces.surfaces_detected;
      
      const prompt = await surveyor.buildSurveyorPrompt(dataWithoutSurfaces);
      expect(prompt).toBeDefined();
      expect(typeof prompt).toBe('string');
    });
  });

  describe('Response Parsing', () => {
    test('should parse valid JSON response', () => {
      const validResponse = JSON.stringify({
        room_type: 'kitchen',
        dimensions_validated: {
          length_ft: 12.5,
          width_ft: 10.0,
          height_ft: 8.5,
          notes: 'Measurements accurate'
        },
        surfaces: {
          flooring: {
            current_material: 'ceramic_tile',
            condition: 'fair',
            removal_required: true,
            subfloor_condition: 'good',
            recommendations: {
              good: 'vinyl_plank',
              better: 'porcelain_tile',
              best: 'natural_stone'
            }
          },
          walls: {
            primary_material: 'drywall',
            condition: 'good',
            repair_needed: ['minor_holes'],
            special_considerations: []
          },
          ceiling: {
            material: 'drywall',
            condition: 'good',
            height_standard: true
          }
        },
        complexity_factors: {
          accessibility: 'standard',
          utilities_present: ['electrical', 'plumbing'],
          structural_considerations: [],
          moisture_concerns: false,
          ventilation_adequate: true
        },
        assembly_recommendations: {
          suggested_assemblies: ['kitchen_standard'],
          customization_needed: [],
          quality_tier_rationale: 'Good existing conditions support standard renovation'
        }
      });

      const result = surveyor.parseAnalysisResult(validResponse, mockScanData);
      expect(result.room_type).toBe('kitchen');
      expect(result.surfaces.flooring.current_material).toBe('ceramic_tile');
    });

    test('should handle malformed JSON with fallback', () => {
      const malformedResponse = '{ "room_type": "kitchen", invalid json }';
      
      const result = surveyor.parseAnalysisResult(malformedResponse, mockScanData);
      expect(result.room_type).toBe('kitchen');
      expect(result.fallback_info).toBeDefined();
      expect(result.fallback_info.error).toContain('Could not parse');
    });

    test('should clean markdown code blocks', () => {
      const responseWithMarkdown = '```json\n{"room_type": "kitchen"}\n```';
      
      // This should not throw an error
      const result = surveyor.parseAnalysisResult(responseWithMarkdown, mockScanData);
      expect(result).toBeDefined();
    });
  });

  describe('Fallback Analysis', () => {
    test('should create fallback analysis with scan data', () => {
      const fallback = surveyor.createFallbackAnalysis(mockScanData, 'invalid response');
      
      expect(fallback.room_type).toBe('kitchen');
      expect(fallback.dimensions_validated.length_ft).toBe(12.5);
      expect(fallback.fallback_info.raw_response).toBe('invalid response');
      expect(fallback.assembly_recommendations.suggested_assemblies).toContain('kitchen_standard');
    });
  });

  describe('Processing Statistics', () => {
    test('should return processing stats', () => {
      const stats = surveyor.getProcessingStats();
      
      expect(stats).toHaveProperty('prompts_loaded');
      expect(stats).toHaveProperty('initialized');
      expect(stats).toHaveProperty('model');
      expect(stats.model).toBe('gemini-1.5-pro');
    });
  });
});

describe('ARFrameProcessor', () => {
  let processor;
  
  beforeEach(() => {
    processor = new ARFrameProcessor();
  });

  describe('Frame Selection', () => {
    test('should select frames evenly across timeline', () => {
      const frames = Array.from({ length: 20 }, (_, i) => ({
        timestamp: `2024-01-15T14:30:${i.toString().padStart(2, '0')}Z`,
        imageData: 'mock-data'
      }));

      const selected = processor.optimizeFrameSelection(frames, 5);
      
      expect(selected).toHaveLength(5);
      expect(selected[0].timestamp).toBe(frames[0].timestamp);
      expect(selected[selected.length - 1].timestamp).toBe(frames[frames.length - 1].timestamp);
    });

    test('should return all frames if count is less than max', () => {
      const frames = [
        { timestamp: '2024-01-15T14:30:00Z', imageData: 'data1' },
        { timestamp: '2024-01-15T14:30:01Z', imageData: 'data2' }
      ];

      const selected = processor.optimizeFrameSelection(frames, 5);
      expect(selected).toHaveLength(2);
    });
  });

  describe('Frame Enhancement', () => {
    test('should add context to frames', () => {
      const frames = [
        { timestamp: '2024-01-15T14:30:00Z', imageData: 'data1' },
        { timestamp: '2024-01-15T14:30:05Z', imageData: 'data2' }
      ];

      const enhanced = processor.enhanceFrameContext(frames);
      
      expect(enhanced[0].sequence_position).toBe(1);
      expect(enhanced[0].total_frames).toBe(2);
      expect(enhanced[1].sequence_position).toBe(2);
    });

    test('should calculate relative timestamps', () => {
      const frames = [
        { timestamp: '2024-01-15T14:30:00Z', imageData: 'data1' },
        { timestamp: '2024-01-15T14:30:30Z', imageData: 'data2' },
        { timestamp: '2024-01-15T14:31:00Z', imageData: 'data3' }
      ];

      const enhanced = processor.enhanceFrameContext(frames);
      
      expect(enhanced[0].relative_timestamp).toBe('0.0');
      expect(enhanced[1].relative_timestamp).toBe('50.0');
      expect(enhanced[2].relative_timestamp).toBe('100.0');
    });
  });

  describe('Data Size Calculation', () => {
    test('should calculate total data size', () => {
      const frames = [
        { imageData: 'dGVzdA==' }, // "test" in base64
        { imageData: 'ZGF0YQ==' }  // "data" in base64
      ];

      const sizeInfo = processor.calculateDataSize(frames);
      
      expect(sizeInfo.frames_count).toBe(2);
      expect(sizeInfo.total_bytes).toBeGreaterThan(0);
      expect(sizeInfo.total_mb).toBeDefined();
    });
  });
});

describe('MeasurementEnricher', () => {
  let enricher;
  let mockDimensions;

  beforeEach(() => {
    enricher = new MeasurementEnricher();
    mockDimensions = {
      length: 12.5,
      width: 10.0,
      height: 8.5
    };
  });

  describe('Area Analysis', () => {
    test('should analyze room measurements', () => {
      const analysis = enricher.analyzeMeasurements(mockDimensions, 'kitchen');
      
      expect(analysis.area_sqft).toBe(125);
      expect(analysis.area_category).toBeDefined();
      expect(analysis.proportions).toBeDefined();
      expect(analysis.height_category).toBeDefined();
    });

    test('should categorize areas correctly', () => {
      const standards = { minArea: 70, maxArea: 300 };
      
      expect(enricher.categorizeArea(50, standards)).toBe('below_standard');
      expect(enricher.categorizeArea(100, standards)).toBe('compact');
      expect(enricher.categorizeArea(250, standards)).toBe('spacious');
      expect(enricher.categorizeArea(400, standards)).toBe('above_standard');
    });
  });

  describe('Proportion Analysis', () => {
    test('should analyze room proportions', () => {
      const proportions = enricher.analyzeProportions(mockDimensions);
      
      expect(proportions.length_to_width_ratio).toBe('1.25');
      expect(proportions.shape_description).toBe('rectangular');
      expect(proportions.longest_dimension).toBe(12.5);
      expect(proportions.shortest_dimension).toBe(10.0);
    });

    test('should identify square rooms', () => {
      const squareDimensions = { length: 10, width: 10, height: 8 };
      const proportions = enricher.analyzeProportions(squareDimensions);
      
      expect(proportions.is_square).toBe(true);
      expect(proportions.shape_description).toBe('square');
    });

    test('should identify narrow rooms', () => {
      const narrowDimensions = { length: 20, width: 6, height: 8 };
      const proportions = enricher.analyzeProportions(narrowDimensions);
      
      expect(proportions.shape_description).toBe('narrow');
    });
  });

  describe('Surface Calculations', () => {
    test('should calculate surface areas', () => {
      const surfaces = enricher.calculateSurfaceAreas(mockDimensions);
      
      expect(surfaces.floor.area_sqft).toBe(125);
      expect(surfaces.ceiling.area_sqft).toBe(125);
      expect(surfaces.walls.gross_area_sqft).toBeGreaterThan(0);
      expect(surfaces.walls.net_area_sqft).toBeLessThan(surfaces.walls.gross_area_sqft);
    });

    test('should estimate openings', () => {
      const openings = enricher.estimateOpenings(mockDimensions, 125);
      
      expect(openings.estimated_doors).toBeGreaterThan(0);
      expect(openings.total_opening_area).toBeGreaterThan(0);
    });
  });

  describe('Space Efficiency', () => {
    test('should assess space efficiency', () => {
      const efficiency = enricher.assessSpaceEfficiency(mockDimensions, 'kitchen');
      
      expect(efficiency.compactness_index).toBeDefined();
      expect(efficiency.efficiency_rating).toBeDefined();
      expect(efficiency.space_utilization_potential).toBeDefined();
    });
  });

  describe('Construction Context', () => {
    test('should add construction context', () => {
      const context = enricher.addConstructionContext(mockDimensions, 'kitchen');
      
      expect(context.material_estimates).toBeDefined();
      expect(context.access_considerations).toBeDefined();
      expect(context.installation_complexity).toBeDefined();
      expect(context.cost_drivers).toBeDefined();
    });

    test('should estimate material quantities', () => {
      const estimates = enricher.estimateMaterialQuantities(mockDimensions);
      
      expect(estimates.flooring_sqft).toBeGreaterThan(125); // Includes waste factor
      expect(estimates.wall_material_sqft).toBeGreaterThan(0);
      expect(estimates.trim_linear_ft).toBeGreaterThan(0);
    });
  });

  describe('Integration', () => {
    test('should create measurement summary', () => {
      const scanData = {
        room_type: 'kitchen',
        dimensions: mockDimensions
      };

      const summary = enricher.createMeasurementSummary(scanData);
      
      expect(summary.room_type).toBe('kitchen');
      expect(summary.basic_dimensions).toEqual(mockDimensions);
      expect(summary.area_analysis).toBeDefined();
      expect(summary.construction_summary).toBeDefined();
      expect(summary.recommendations).toBeDefined();
    });
  });
});

// Integration Tests
describe('Service Integration', () => {
  test('should integrate all components for full analysis', async () => {
    // This would require actual Gemini API mocking
    // For now, test that the components work together structurally
    
    const processor = new ARFrameProcessor();
    const enricher = new MeasurementEnricher();
    
    const mockScanData = {
      scan_id: 'integration-test',
      room_type: 'kitchen',
      dimensions: { length: 12, width: 10, height: 8.5, total_area: 120 },
      frames: [
        { timestamp: '2024-01-15T14:30:00Z', imageData: 'test-data', lighting_conditions: 'good' }
      ]
    };

    // Test frame processing
    const optimizedFrames = processor.optimizeFrameSelection(mockScanData.frames, 5);
    expect(optimizedFrames).toBeDefined();

    // Test measurement enrichment
    const enrichedData = enricher.enrichScanData(mockScanData);
    expect(enrichedData.measurement_analysis).toBeDefined();

    // Verify integration points
    expect(enrichedData.surface_calculations.floor.area_sqft).toBe(120);
  });
});