-- ContractorLens Location Modifier Validation Queries
-- Database Engineer: DB003 - Validate geographic cost multiplier accuracy and integration
-- Version: 1.0
-- Created: 2025-09-04

SET search_path TO contractorlens, public;

-- =============================================================================
-- LOCATION MODIFIER VALIDATION SUITE
-- Tests the accuracy and completeness of geographic cost multipliers
-- Simulates Assembly Engine integration patterns
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. GEOGRAPHIC COVERAGE VERIFICATION
-- Ensure all major US construction markets are covered
-- -----------------------------------------------------------------------------

SELECT 
    '=== GEOGRAPHIC COVERAGE VERIFICATION ===' as test_name;

-- Show all metros organized by cost tier
SELECT 
    CASE 
        WHEN material_modifier >= 1.40 THEN '🔴 Premium (140%+)'
        WHEN material_modifier >= 1.20 THEN '🟠 High Cost (120-139%)'
        WHEN material_modifier >= 1.05 THEN '🟡 Above Average (105-119%)'
        WHEN material_modifier >= 0.95 THEN '🟢 Average (95-104%)'
        ELSE '🔵 Below Average (<95%)'
    END as cost_tier,
    metro_name,
    state_code,
    material_modifier,
    labor_modifier,
    ROUND((material_modifier - 1.0) * 100, 1) || '% materials' as material_diff,
    ROUND((labor_modifier - 1.0) * 100, 1) || '% labor' as labor_diff,
    zip_code_range
FROM LocationCostModifiers 
WHERE metro_name != 'National Baseline'
ORDER BY material_modifier DESC, metro_name;

-- Coverage summary by state
SELECT 
    '=== COVERAGE BY STATE ===' as summary_name;

SELECT 
    state_code,
    COUNT(*) as metro_count,
    ROUND(MIN(material_modifier), 3) as lowest_material,
    ROUND(MAX(material_modifier), 3) as highest_material,
    ROUND(AVG(material_modifier), 3) as avg_material,
    ROUND(MIN(labor_modifier), 3) as lowest_labor,
    ROUND(MAX(labor_modifier), 3) as highest_labor,
    ROUND(AVG(labor_modifier), 3) as avg_labor
FROM LocationCostModifiers 
WHERE metro_name != 'National Baseline'
GROUP BY state_code
ORDER BY state_code;

-- -----------------------------------------------------------------------------
-- 2. COST HIERARCHY INTEGRATION TEST
-- Test the exact cost calculation logic Assembly Engine will use
-- -----------------------------------------------------------------------------

SELECT 
    '=== COST HIERARCHY INTEGRATION TEST ===' as test_name;

-- Simulate Assembly Engine cost calculation for sample item
WITH cost_hierarchy_test AS (
    SELECT 
        lcm.metro_name,
        -- National average cost for sample item (quartz countertop)
        85.00 as national_average_cost,
        -- Apply location modifier (step 2 of cost hierarchy)
        ROUND((85.00 * lcm.material_modifier)::numeric, 2) as localized_cost,
        lcm.material_modifier,
        -- Show cost difference from baseline
        ROUND((85.00 * lcm.material_modifier - 85.00)::numeric, 2) as cost_increase,
        ROUND(((lcm.material_modifier - 1.0) * 100)::numeric, 1) as percent_increase
    FROM LocationCostModifiers lcm
    WHERE lcm.metro_name IN (
        'San Francisco, CA',
        'New York, NY', 
        'Chicago, IL',
        'Miami, FL',
        'Atlanta, GA',
        'Kansas City, MO'
    )
)
SELECT 
    metro_name,
    '$' || national_average_cost as national_cost,
    '$' || localized_cost as localized_cost,
    '+$' || cost_increase as cost_difference,
    percent_increase || '%' as percent_change,
    material_modifier as multiplier
FROM cost_hierarchy_test
ORDER BY localized_cost DESC;

-- -----------------------------------------------------------------------------
-- 3. REALISTIC PROJECT ESTIMATES BY LOCATION
-- Test complete kitchen/bathroom estimates across different markets
-- -----------------------------------------------------------------------------

SELECT 
    '=== REALISTIC PROJECT ESTIMATES BY LOCATION ===' as test_name;

-- Kitchen Standard Package cost by major metros
WITH kitchen_estimates AS (
    SELECT 
        'Kitchen Standard Package (120 SF)' as project_type,
        lcm.metro_name,
        lcm.state_code,
        
        -- Base costs from assembly calculations (from DB002)
        8500.00 as base_material_cost,
        120 as labor_hours,
        45.00 as hourly_rate,
        
        -- Apply location modifiers
        ROUND((8500.00 * lcm.material_modifier)::numeric, 0) as localized_material,
        ROUND((120 * 45.00 * lcm.labor_modifier)::numeric, 0) as localized_labor,
        ROUND((
            (8500.00 * lcm.material_modifier) + 
            (120 * 45.00 * lcm.labor_modifier)
        )::numeric, 0) as total_estimate,
        
        -- Show modifiers for reference
        lcm.material_modifier,
        lcm.labor_modifier
    FROM LocationCostModifiers lcm
    WHERE lcm.metro_name IN (
        'San Francisco, CA', 'Los Angeles, CA', 'Seattle, WA',
        'New York, NY', 'Boston, MA', 'Miami, FL',
        'Chicago, IL', 'Denver, CO', 'Atlanta, GA', 
        'Dallas, TX', 'Kansas City, MO'
    )
)
SELECT 
    project_type,
    metro_name,
    state_code,
    '$' || localized_material as materials,
    '$' || localized_labor as labor,
    '$' || total_estimate as total_project_cost,
    ROUND(((total_estimate / (8500.00 + (120 * 45.00)) - 1.0) * 100)::numeric, 1) || '%' as vs_baseline
FROM kitchen_estimates
ORDER BY total_estimate DESC;

-- Bathroom Premium Package cost by major metros  
WITH bathroom_estimates AS (
    SELECT 
        'Bathroom Premium Package (50 SF)' as project_type,
        lcm.metro_name,
        
        -- Base costs for premium bathroom
        12000.00 as base_material_cost,
        85 as labor_hours,
        45.00 as hourly_rate,
        
        -- Apply location modifiers
        ROUND((12000.00 * lcm.material_modifier)::numeric, 0) as localized_material,
        ROUND((85 * 45.00 * lcm.labor_modifier)::numeric, 0) as localized_labor,
        ROUND((
            (12000.00 * lcm.material_modifier) + 
            (85 * 45.00 * lcm.labor_modifier)
        )::numeric, 0) as total_estimate
    FROM LocationCostModifiers lcm
    WHERE lcm.metro_name IN (
        'Manhattan, NY', 'Beverly Hills, CA', 'Aspen, CO',
        'Miami Beach, FL', 'Napa, CA', 'Boston, MA'
    )
)
SELECT 
    project_type,
    metro_name,
    '$' || localized_material as materials,
    '$' || localized_labor as labor, 
    '$' || total_estimate as total_project_cost
FROM bathroom_estimates
ORDER BY total_estimate DESC;

-- -----------------------------------------------------------------------------
-- 4. ZIP CODE COVERAGE ANALYSIS
-- Verify zip code range patterns for location matching
-- -----------------------------------------------------------------------------

SELECT 
    '=== ZIP CODE COVERAGE ANALYSIS ===' as test_name;

-- Analyze zip code prefix distribution
SELECT 
    SUBSTRING(zip_code_range FROM 1 FOR 2) as zip_prefix,
    SUBSTRING(zip_code_range FROM 1 FOR 3) as zip_3digit,
    COUNT(*) as location_count,
    STRING_AGG(DISTINCT state_code, ', ' ORDER BY state_code) as states_covered,
    ROUND(AVG(material_modifier)::numeric, 3) as avg_material_mod,
    ROUND(MIN(material_modifier)::numeric, 3) as min_material_mod,
    ROUND(MAX(material_modifier)::numeric, 3) as max_material_mod
FROM LocationCostModifiers 
WHERE metro_name != 'National Baseline'
  AND LENGTH(zip_code_range) >= 5
GROUP BY SUBSTRING(zip_code_range FROM 1 FOR 2), SUBSTRING(zip_code_range FROM 1 FOR 3)
ORDER BY zip_prefix, zip_3digit;

-- Test specific zip code lookups (Assembly Engine simulation)
SELECT 
    '=== ASSEMBLY ENGINE ZIP CODE LOOKUP SIMULATION ===' as test_name;

-- Simulate exact Assembly Engine query pattern
WITH zip_lookup_tests AS (
    SELECT unnest(ARRAY[
        '10001', '94105', '90210', '98101', '60601',  -- Major cities
        '02138', '33139', '80202', '75201', '30309'   -- More test zips
    ]) as test_zip
)
SELECT 
    zlt.test_zip as lookup_zip,
    lcm.metro_name,
    lcm.state_code,
    lcm.zip_code_range,
    lcm.material_modifier,
    lcm.labor_modifier,
    CASE 
        WHEN zlt.test_zip BETWEEN SPLIT_PART(lcm.zip_code_range, '-', 1) 
                               AND COALESCE(SPLIT_PART(lcm.zip_code_range, '-', 2), SPLIT_PART(lcm.zip_code_range, '-', 1))
        THEN '✅ MATCH'
        ELSE '❌ NO MATCH'
    END as zip_match_status
FROM zip_lookup_tests zlt
CROSS JOIN LocationCostModifiers lcm
WHERE lcm.metro_name != 'National Baseline'
  AND zlt.test_zip BETWEEN SPLIT_PART(lcm.zip_code_range, '-', 1) 
                        AND COALESCE(SPLIT_PART(lcm.zip_code_range, '-', 2), SPLIT_PART(lcm.zip_code_range, '-', 1))
ORDER BY zlt.test_zip, lcm.material_modifier DESC;

-- -----------------------------------------------------------------------------
-- 5. DATA QUALITY AND INTEGRITY CHECKS
-- Validate data consistency and identify potential issues
-- -----------------------------------------------------------------------------

SELECT 
    '=== DATA QUALITY AND INTEGRITY CHECKS ===' as test_name;

-- Check for invalid modifiers
SELECT 
    'Invalid Modifiers (should be 0)' as check_name,
    COUNT(*) as issue_count
FROM LocationCostModifiers
WHERE material_modifier IS NULL 
   OR labor_modifier IS NULL 
   OR material_modifier <= 0 
   OR labor_modifier <= 0
   OR material_modifier > 2.0  -- Unreasonably high
   OR labor_modifier > 2.0;

-- Check for overlapping zip code ranges
SELECT 
    'Overlapping ZIP Ranges' as check_name,
    COUNT(*) as potential_overlaps
FROM LocationCostModifiers l1
CROSS JOIN LocationCostModifiers l2
WHERE l1.location_id != l2.location_id
  AND l1.state_code = l2.state_code
  AND l1.metro_name != 'National Baseline'
  AND l2.metro_name != 'National Baseline'
  AND SPLIT_PART(l1.zip_code_range, '-', 1) <= SPLIT_PART(l2.zip_code_range, '-', 2)
  AND SPLIT_PART(l2.zip_code_range, '-', 1) <= SPLIT_PART(l1.zip_code_range, '-', 2);

-- Check modifier reasonableness (industry standards)
SELECT 
    'Unreasonable Modifiers' as check_name,
    COUNT(*) as issue_count
FROM LocationCostModifiers
WHERE (material_modifier < 0.5 OR material_modifier > 2.0)
   OR (labor_modifier < 0.5 OR labor_modifier > 2.5)
   AND metro_name != 'National Baseline';

-- Check effective date consistency
SELECT 
    'Future Effective Dates' as check_name,
    COUNT(*) as issue_count
FROM LocationCostModifiers
WHERE effective_date > CURRENT_DATE;

-- Material vs Labor modifier relationship analysis
SELECT 
    'Modifier Relationship Analysis' as analysis_name,
    COUNT(*) as total_locations,
    COUNT(CASE WHEN labor_modifier > material_modifier THEN 1 END) as labor_higher,
    COUNT(CASE WHEN material_modifier > labor_modifier THEN 1 END) as material_higher,
    COUNT(CASE WHEN material_modifier = labor_modifier THEN 1 END) as equal_modifiers,
    ROUND(AVG(labor_modifier - material_modifier)::numeric, 3) as avg_labor_premium
FROM LocationCostModifiers
WHERE metro_name != 'National Baseline';

-- -----------------------------------------------------------------------------
-- 6. ASSEMBLY ENGINE PERFORMANCE SIMULATION
-- Test query performance patterns Assembly Engine will use
-- -----------------------------------------------------------------------------

SELECT 
    '=== ASSEMBLY ENGINE PERFORMANCE SIMULATION ===' as test_name;

-- Simulate high-frequency location lookups
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    lcm.material_modifier,
    lcm.labor_modifier,
    lcm.metro_name
FROM LocationCostModifiers lcm
WHERE lcm.state_code = 'CA'
  AND '94105' BETWEEN SPLIT_PART(lcm.zip_code_range, '-', 1) 
                  AND COALESCE(SPLIT_PART(lcm.zip_code_range, '-', 2), SPLIT_PART(lcm.zip_code_range, '-', 1))
  AND lcm.effective_date <= CURRENT_DATE
  AND (lcm.expiry_date IS NULL OR lcm.expiry_date > CURRENT_DATE)
ORDER BY 
    CASE WHEN lcm.metro_name = 'National Baseline' THEN 1 ELSE 0 END,
    lcm.material_modifier DESC
LIMIT 1;

-- Test Assembly Engine cost calculation with joins
EXPLAIN (ANALYZE, BUFFERS)
WITH sample_calculation AS (
    SELECT 
        ai.quantity,
        i.national_average_cost,
        i.item_type,
        lcm.material_modifier,
        lcm.labor_modifier
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    CROSS JOIN LocationCostModifiers lcm
    WHERE a.name = 'Kitchen Standard Package'
      AND lcm.metro_name = 'San Francisco, CA'
    LIMIT 10
)
SELECT 
    SUM(
        CASE 
            WHEN item_type = 'material' THEN 
                quantity * 120 * national_average_cost * material_modifier
            WHEN item_type = 'labor' THEN 
                quantity * 120 * national_average_cost * labor_modifier  
        END
    ) as total_estimate
FROM sample_calculation;

-- -----------------------------------------------------------------------------
-- 7. TIER VALIDATION AND MARKET REALITY CHECK
-- Verify cost tiers align with real market conditions
-- -----------------------------------------------------------------------------

SELECT 
    '=== TIER VALIDATION AND MARKET REALITY CHECK ===' as test_name;

-- Major metros tier validation
WITH market_tiers AS (
    SELECT 
        metro_name,
        state_code,
        material_modifier,
        labor_modifier,
        CASE 
            WHEN material_modifier >= 1.40 THEN 'Premium'
            WHEN material_modifier >= 1.20 THEN 'High Cost'
            WHEN material_modifier >= 1.05 THEN 'Above Average'
            WHEN material_modifier >= 0.95 THEN 'Average'
            ELSE 'Below Average'
        END as assigned_tier,
        -- Expected tier based on market knowledge
        CASE 
            WHEN metro_name IN ('San Francisco, CA', 'Manhattan, NY', 'Beverly Hills, CA', 'Aspen, CO') THEN 'Premium'
            WHEN metro_name IN ('New York, NY', 'Los Angeles, CA', 'Seattle, WA', 'Boston, MA') THEN 'High Cost'
            WHEN metro_name IN ('Chicago, IL', 'Miami, FL', 'Denver, CO', 'Portland, OR') THEN 'Above Average'
            WHEN metro_name IN ('Atlanta, GA', 'Dallas, TX', 'Phoenix, AZ') THEN 'Average'
            WHEN metro_name IN ('Kansas City, MO', 'Oklahoma City, OK', 'Louisville, KY') THEN 'Below Average'
            ELSE 'Unknown'
        END as expected_tier
    FROM LocationCostModifiers
    WHERE metro_name != 'National Baseline'
)
SELECT 
    metro_name,
    assigned_tier,
    expected_tier,
    material_modifier,
    CASE 
        WHEN assigned_tier = expected_tier THEN '✅ CORRECT'
        ELSE '⚠️ CHECK NEEDED'
    END as validation_status
FROM market_tiers
WHERE expected_tier != 'Unknown'
ORDER BY material_modifier DESC;

-- Labor vs Material modifier reasonableness check
SELECT 
    '=== LABOR VS MATERIAL MODIFIER ANALYSIS ===' as analysis_name;

SELECT 
    metro_name,
    material_modifier,
    labor_modifier,
    ROUND((labor_modifier - material_modifier)::numeric, 3) as labor_premium,
    CASE 
        WHEN labor_modifier > material_modifier + 0.15 THEN '🔴 High Labor Premium'
        WHEN labor_modifier > material_modifier + 0.05 THEN '🟡 Moderate Labor Premium'
        WHEN ABS(labor_modifier - material_modifier) <= 0.05 THEN '🟢 Balanced'
        ELSE '🔵 Material Premium'
    END as relationship_type
FROM LocationCostModifiers
WHERE metro_name != 'National Baseline'
ORDER BY (labor_modifier - material_modifier) DESC;

-- -----------------------------------------------------------------------------
-- 8. FINAL INTEGRATION READINESS TEST
-- Complete end-to-end Assembly Engine simulation
-- -----------------------------------------------------------------------------

SELECT 
    '=== FINAL INTEGRATION READINESS TEST ===' as test_name;

-- Complete Assembly Engine workflow simulation
WITH integration_test AS (
    -- Step 1: User requests estimate for Kitchen Standard in San Francisco
    SELECT 
        'San Francisco, CA' as requested_location,
        'Kitchen Standard Package' as requested_assembly,
        120 as room_size_sf,
        
        -- Step 2: Look up location modifiers
        lcm.material_modifier,
        lcm.labor_modifier,
        
        -- Step 3: Get assembly items and calculate costs
        ai.quantity,
        i.description,
        i.item_type,
        i.national_average_cost,
        
        -- Step 4: Apply location modifiers to costs
        CASE 
            WHEN i.item_type = 'material' THEN 
                ai.quantity * 120 * i.national_average_cost * lcm.material_modifier
            WHEN i.item_type = 'labor' THEN 
                ai.quantity * 120 * i.national_average_cost * lcm.labor_modifier
        END as localized_line_cost
        
    FROM LocationCostModifiers lcm
    CROSS JOIN Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    WHERE lcm.metro_name = 'San Francisco, CA'
      AND a.name = 'Kitchen Standard Package'
    LIMIT 5  -- Sample items for demonstration
)
SELECT 
    requested_location,
    requested_assembly,
    room_size_sf || ' SF' as room_size,
    description as item,
    item_type,
    '$' || ROUND(national_average_cost::numeric, 2) as national_cost,
    material_modifier || 'x' as mat_modifier,
    labor_modifier || 'x' as lab_modifier, 
    '$' || ROUND(localized_line_cost::numeric, 2) as localized_cost
FROM integration_test;

-- Final validation summary
SELECT 
    '=== VALIDATION COMPLETE ===' as test_name,
    'Location modifiers ready for Assembly Engine integration!' as status,
    (SELECT COUNT(*) FROM LocationCostModifiers WHERE metro_name != 'National Baseline') as total_locations,
    'Geographic cost accuracy enabled nationwide! 🗺️💰' as result;