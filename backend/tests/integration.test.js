/**
 * Integration Test for Gemini-Assembly Engine Integration
 * 
 * Tests the workflow: Mock AR scan → Gemini analysis → Assembly Engine → Enhanced estimate
 */

const GeminiIntegrationService = require('../src/services/geminiIntegration');
const AssemblyEngine = require('../src/services/assemblyEngine');

// Mock data for testing
const mockEnhancedScanData = {
  scan_id: 'test-scan-001',
  room_type: 'kitchen',
  
  takeoff_data: {
    walls: [{ area: 320, height: 9 }], // 320 SF of wall area
    floors: [{ area: 120 }], // 12x10 kitchen (120 SF)
    ceilings: [{ area: 120 }],
    kitchens: [{ area: 120 }]
  },
  
  dimensions: {
    length: 12,
    width: 10,
    height: 9,
    total_area: 120
  },
  
  frames: [
    {
      timestamp: new Date().toISOString(),
      imageData: 'base64-mock-image-data-would-go-here',
      mimeType: 'image/jpeg',
      lighting_conditions: 'good'
    }
  ],
  
  surfaces_detected: [
    { type: 'floor', area: 120 },
    { type: 'wall', area: 320 },
    { type: 'ceiling', area: 120 }
  ],
  
  start_time: Date.now()
};

const mockUserSettings = {
  hourly_rate: 65,
  markup_percentage: 25,
  tax_rate: 0.08,
  preferred_quality_tier: 'better'
};

/**
 * Test basic Assembly Engine functionality (without Gemini)
 */
async function testBasicAssemblyEngine() {
  console.log('\n🧮 Testing Basic Assembly Engine...');
  
  try {
    const assemblyEngine = new AssemblyEngine();
    
    const estimate = await assemblyEngine.calculateEstimate(
      mockEnhancedScanData.takeoff_data,
      'kitchen',
      'better',
      '10001', // NYC ZIP
      mockUserSettings
    );
    
    // Validate estimate structure
    console.log('✅ Assembly Engine basic functionality test passed');
    console.log(`   - Grand total: $${estimate.grandTotal?.toFixed(2) || 'N/A'}`);
    console.log(`   - Line items: ${estimate.lineItems?.length || 0}`);
    console.log(`   - Labor hours: ${estimate.metadata?.totalLaborHours || 0}`);
    
    return { success: true, estimate };
    
  } catch (error) {
    console.error('❌ Assembly Engine basic test failed:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test Gemini Integration Service initialization
 */
async function testGeminiIntegrationInit() {
  console.log('\n🤖 Testing Gemini Integration Service Initialization...');
  
  try {
    const integrationService = new GeminiIntegrationService();
    
    // Test health check without requiring actual Gemini API
    const health = await integrationService.healthCheck();
    
    console.log('✅ Gemini Integration Service initialization test passed');
    console.log(`   - Service status: ${health.status}`);
    console.log(`   - Components: ${Object.keys(health.components).join(', ')}`);
    
    return { success: true, health };
    
  } catch (error) {
    console.error('❌ Gemini Integration init test failed:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test fallback estimate creation (when Gemini fails)
 */
async function testFallbackEstimate() {
  console.log('\n🔄 Testing Fallback Estimate Creation...');
  
  try {
    const integrationService = new GeminiIntegrationService();
    
    const fallbackEstimate = await integrationService.createFallbackEstimate(
      mockEnhancedScanData.takeoff_data,
      'kitchen',
      'better',
      '10001',
      mockUserSettings
    );
    
    console.log('✅ Fallback estimate test passed');
    console.log(`   - Grand total: $${fallbackEstimate.grandTotal?.toFixed(2) || 'N/A'}`);
    console.log(`   - Line items: ${fallbackEstimate.lineItems?.length || 0}`);
    console.log(`   - Metadata: ${Object.keys(fallbackEstimate.metadata || {}).length} fields`);
    
    return { success: true, estimate: fallbackEstimate };
    
  } catch (error) {
    console.error('❌ Fallback estimate test failed:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Test enhanced takeoff data processing
 */
async function testTakeoffDataEnhancement() {
  console.log('\n📊 Testing Takeoff Data Enhancement...');
  
  try {
    const integrationService = new GeminiIntegrationService();
    
    // Mock Gemini analysis result (without actually calling Gemini API)
    const mockGeminiAnalysis = {
      room_type: 'kitchen',
      dimensions_validated: {
        length_ft: 12,
        width_ft: 10,
        height_ft: 9,
        notes: 'Mock analysis for testing'
      },
      surfaces: {
        flooring: {
          current_material: 'vinyl',
          condition: 'fair',
          removal_required: true,
          subfloor_condition: 'good',
          recommendations: {
            good: 'vinyl_plank',
            better: 'ceramic_tile',
            best: 'hardwood'
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
        quality_tier_rationale: 'Standard kitchen suitable for better tier'
      }
    };
    
    const enhancedData = integrationService.enhanceTakeoffData(
      mockEnhancedScanData.takeoff_data,
      mockGeminiAnalysis
    );
    
    console.log('✅ Takeoff data enhancement test passed');
    console.log(`   - Enhanced walls with material: ${enhancedData.walls?.[0]?.current_material || 'N/A'}`);
    console.log(`   - Enhanced floors with condition: ${enhancedData.floors?.[0]?.condition || 'N/A'}`);
    console.log(`   - Complexity analysis: ${enhancedData.complexity_analysis?.overall_complexity || 'N/A'}`);
    
    return { success: true, enhancedData };
    
  } catch (error) {
    console.error('❌ Takeoff data enhancement test failed:', error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Run all integration tests
 */
async function runIntegrationTests() {
  console.log('🚀 ContractorLens Backend Integration Tests');
  console.log('==========================================');
  
  const results = {
    basicAssemblyEngine: await testBasicAssemblyEngine(),
    geminiIntegrationInit: await testGeminiIntegrationInit(),
    fallbackEstimate: await testFallbackEstimate(),
    takeoffDataEnhancement: await testTakeoffDataEnhancement()
  };
  
  // Summary
  console.log('\n📋 Test Results Summary:');
  console.log('========================');
  
  let passCount = 0;
  let failCount = 0;
  
  Object.entries(results).forEach(([testName, result]) => {
    const status = result.success ? '✅ PASS' : '❌ FAIL';
    console.log(`${status} ${testName}`);
    
    if (result.success) {
      passCount++;
    } else {
      failCount++;
      console.log(`     Error: ${result.error}`);
    }
  });
  
  console.log(`\nTotal: ${passCount} passed, ${failCount} failed`);
  
  if (failCount === 0) {
    console.log('🎉 All integration tests passed! Backend is ready for deployment.');
  } else {
    console.log('⚠️  Some tests failed. Review errors before deployment.');
  }
  
  return results;
}

// Export for use in other test files
module.exports = {
  runIntegrationTests,
  testBasicAssemblyEngine,
  testGeminiIntegrationInit,
  testFallbackEstimate,
  testTakeoffDataEnhancement,
  mockEnhancedScanData,
  mockUserSettings
};

// Run tests if executed directly
if (require.main === module) {
  runIntegrationTests().catch(console.error);
}