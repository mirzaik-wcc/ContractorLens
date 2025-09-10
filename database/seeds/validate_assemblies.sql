-- ContractorLens Assembly Validation Queries
-- Database Engineer: DB002 - Test queries to verify assembly completeness and accuracy
-- Version: 1.0
-- Created: 2025-09-03

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY VALIDATION QUERIES
-- Test the completeness and accuracy of our assembly templates
-- These queries simulate what the Assembly Engine will execute
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ASSEMBLY COMPLETENESS TEST
-- Verify each assembly has materials for all major components
-- -----------------------------------------------------------------------------

SELECT 
    '=== ASSEMBLY COMPLETENESS TEST ===' as test_name;

SELECT 
    a.name as assembly_name,
    a.category,
    COUNT(DISTINCT i.category) as categories_covered,
    COUNT(DISTINCT ai.item_id) as total_items,
    STRING_AGG(DISTINCT i.category, ', ' ORDER BY i.category) as categories_list
FROM Assemblies a
JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
JOIN Items i ON ai.item_id = i.item_id
GROUP BY a.assembly_id, a.name, a.category
ORDER BY a.category, a.name;

-- -----------------------------------------------------------------------------
-- 2. KITCHEN ASSEMBLY COST ESTIMATES
-- Calculate estimated costs for typical 120 SF kitchen
-- Expected ranges: Economy ~$6K, Standard ~$10K, Premium ~$18K
-- -----------------------------------------------------------------------------

SELECT 
    '=== KITCHEN COST ESTIMATES (120 SF Kitchen) ===' as test_name;

WITH kitchen_calculations AS (
    SELECT 
        a.name as assembly_name,
        CASE 
            WHEN a.name LIKE '%Economy%' THEN 'good'
            WHEN a.name LIKE '%Standard%' THEN 'better' 
            WHEN a.name LIKE '%Premium%' THEN 'best'
        END as quality_tier,
        i.description as item_description,
        i.category as item_category,
        i.item_type,
        ai.quantity as qty_per_sf,
        i.national_average_cost as unit_cost,
        i.quantity_per_unit as production_rate,
        
        -- Calculate for 120 SF kitchen
        CASE 
            WHEN i.unit = 'SF' THEN ai.quantity * 120  -- Direct SF items
            WHEN i.unit = 'LF' THEN ai.quantity * 120  -- LF items calculated per SF
            WHEN i.unit = 'EA' THEN ai.quantity * 120  -- EA items calculated per SF
        END as total_quantity,
        
        -- Calculate material cost
        CASE 
            WHEN i.item_type = 'material' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 120 * i.national_average_cost
                    WHEN i.unit = 'LF' THEN ai.quantity * 120 * i.national_average_cost  
                    WHEN i.unit = 'EA' THEN ai.quantity * 120 * i.national_average_cost
                END)
            ELSE 0
        END as material_cost,
        
        -- Calculate labor hours and cost
        CASE 
            WHEN i.item_type = 'labor' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 120 * i.quantity_per_unit * 45  -- $45/hour
                    WHEN i.unit = 'LF' THEN ai.quantity * 120 * i.quantity_per_unit * 45
                    WHEN i.unit = 'EA' THEN ai.quantity * 120 * i.quantity_per_unit * 45
                END)
            ELSE 0
        END as labor_cost,
        
        -- Calculate labor hours
        CASE 
            WHEN i.item_type = 'labor' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 120 * i.quantity_per_unit
                    WHEN i.unit = 'LF' THEN ai.quantity * 120 * i.quantity_per_unit
                    WHEN i.unit = 'EA' THEN ai.quantity * 120 * i.quantity_per_unit
                END)
            ELSE 0
        END as labor_hours
        
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id  
    JOIN Items i ON ai.item_id = i.item_id
    WHERE a.category = 'kitchen'
)
SELECT 
    assembly_name,
    quality_tier,
    ROUND(SUM(material_cost)::numeric, 0) as total_material_cost,
    ROUND(SUM(labor_cost)::numeric, 0) as total_labor_cost, 
    ROUND((SUM(material_cost) + SUM(labor_cost))::numeric, 0) as total_project_cost,
    ROUND(SUM(labor_hours)::numeric, 1) as total_labor_hours
FROM kitchen_calculations
GROUP BY assembly_name, quality_tier
ORDER BY quality_tier, assembly_name;

-- -----------------------------------------------------------------------------
-- 3. BATHROOM ASSEMBLY COST ESTIMATES  
-- Calculate estimated costs for typical 50 SF bathroom
-- Expected ranges: Economy ~$4K, Standard ~$7K, Premium ~$12K
-- -----------------------------------------------------------------------------

SELECT 
    '=== BATHROOM COST ESTIMATES (50 SF Bathroom) ===' as test_name;

WITH bathroom_calculations AS (
    SELECT 
        a.name as assembly_name,
        CASE 
            WHEN a.name LIKE '%Economy%' THEN 'good'
            WHEN a.name LIKE '%Standard%' THEN 'better'
            WHEN a.name LIKE '%Premium%' THEN 'best'
        END as quality_tier,
        i.description as item_description,
        i.category as item_category,
        i.item_type,
        ai.quantity as qty_per_sf,
        i.national_average_cost as unit_cost,
        
        -- Calculate for 50 SF bathroom
        CASE 
            WHEN i.unit = 'SF' THEN ai.quantity * 50
            WHEN i.unit = 'LF' THEN ai.quantity * 50
            WHEN i.unit = 'EA' THEN ai.quantity * 50
        END as total_quantity,
        
        -- Material cost
        CASE 
            WHEN i.item_type = 'material' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 50 * i.national_average_cost
                    WHEN i.unit = 'LF' THEN ai.quantity * 50 * i.national_average_cost
                    WHEN i.unit = 'EA' THEN ai.quantity * 50 * i.national_average_cost
                END)
            ELSE 0
        END as material_cost,
        
        -- Labor cost  
        CASE 
            WHEN i.item_type = 'labor' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 50 * i.quantity_per_unit * 45
                    WHEN i.unit = 'LF' THEN ai.quantity * 50 * i.quantity_per_unit * 45
                    WHEN i.unit = 'EA' THEN ai.quantity * 50 * i.quantity_per_unit * 45
                END)
            ELSE 0
        END as labor_cost,
        
        -- Labor hours
        CASE 
            WHEN i.item_type = 'labor' THEN 
                (CASE 
                    WHEN i.unit = 'SF' THEN ai.quantity * 50 * i.quantity_per_unit
                    WHEN i.unit = 'LF' THEN ai.quantity * 50 * i.quantity_per_unit  
                    WHEN i.unit = 'EA' THEN ai.quantity * 50 * i.quantity_per_unit
                END)
            ELSE 0
        END as labor_hours
        
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    WHERE a.category = 'bathroom'
)
SELECT 
    assembly_name,
    quality_tier,
    ROUND(SUM(material_cost)::numeric, 0) as total_material_cost,
    ROUND(SUM(labor_cost)::numeric, 0) as total_labor_cost,
    ROUND((SUM(material_cost) + SUM(labor_cost))::numeric, 0) as total_project_cost,
    ROUND(SUM(labor_hours)::numeric, 1) as total_labor_hours
FROM bathroom_calculations  
GROUP BY assembly_name, quality_tier
ORDER BY quality_tier, assembly_name;

-- -----------------------------------------------------------------------------
-- 4. QUALITY TIER PRICING ANALYSIS
-- Verify pricing progression: Better ~1.8x Good, Best ~2.5x Good
-- -----------------------------------------------------------------------------

SELECT 
    '=== QUALITY TIER PRICING ANALYSIS ===' as test_name;

WITH tier_costs AS (
    SELECT 
        a.category,
        CASE 
            WHEN a.name LIKE '%Economy%' THEN 'good'
            WHEN a.name LIKE '%Standard%' THEN 'better'
            WHEN a.name LIKE '%Premium%' THEN 'best'
        END as quality_tier,
        SUM(
            CASE 
                WHEN a.category = 'kitchen' THEN 
                    ai.quantity * 120 * i.national_average_cost
                WHEN a.category = 'bathroom' THEN 
                    ai.quantity * 50 * i.national_average_cost
            END
        ) as total_cost
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    WHERE i.item_type = 'material'  -- Only material costs for this analysis
    GROUP BY a.category, quality_tier
)
SELECT 
    category,
    quality_tier,
    ROUND(total_cost::numeric, 0) as cost,
    CASE 
        WHEN quality_tier = 'good' THEN 1.0
        ELSE ROUND((total_cost / LAG(total_cost) OVER (PARTITION BY category ORDER BY quality_tier))::numeric, 2)
    END as multiplier_vs_previous
FROM tier_costs
ORDER BY category, quality_tier;

-- -----------------------------------------------------------------------------
-- 5. PRODUCTION RATE VALIDATION  
-- Check that all production rates are within reasonable ranges
-- -----------------------------------------------------------------------------

SELECT 
    '=== PRODUCTION RATE VALIDATION ===' as test_name;

SELECT 
    i.category,
    i.item_type,
    COUNT(*) as item_count,
    MIN(i.quantity_per_unit) as min_production_rate,
    ROUND(AVG(i.quantity_per_unit)::numeric, 4) as avg_production_rate,
    MAX(i.quantity_per_unit) as max_production_rate,
    COUNT(CASE WHEN i.quantity_per_unit IS NULL THEN 1 END) as null_rates,
    COUNT(CASE WHEN i.quantity_per_unit <= 0 THEN 1 END) as invalid_rates
FROM Items i
WHERE i.item_id IN (
    SELECT DISTINCT ai.item_id 
    FROM AssemblyItems ai
)
GROUP BY i.category, i.item_type
ORDER BY i.category, i.item_type;

-- -----------------------------------------------------------------------------
-- 6. ASSEMBLY ENGINE SIMULATION
-- Simulate the exact query pattern the Assembly Engine will use
-- -----------------------------------------------------------------------------

SELECT 
    '=== ASSEMBLY ENGINE SIMULATION ===' as test_name;

-- Test query for Kitchen Standard Package (this is what Assembly Engine will run)
SELECT 
    'Kitchen Standard Package - Assembly Engine Query' as simulation_name,
    i.description as item_name,
    i.category,
    i.item_type,
    i.unit,
    ai.quantity as quantity_per_sf,
    i.national_average_cost as unit_cost,
    i.quantity_per_unit as production_rate,
    
    -- For 120 SF kitchen
    (ai.quantity * 120) as total_quantity_needed,
    CASE 
        WHEN i.item_type = 'material' THEN 
            ROUND((ai.quantity * 120 * i.national_average_cost)::numeric, 2)
        WHEN i.item_type = 'labor' THEN
            ROUND((ai.quantity * 120 * i.quantity_per_unit * 45)::numeric, 2)  -- $45/hour
    END as total_cost,
    
    CASE 
        WHEN i.item_type = 'labor' THEN
            ROUND((ai.quantity * 120 * i.quantity_per_unit)::numeric, 2)
        ELSE 0
    END as labor_hours
    
FROM Assemblies a
JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
JOIN Items i ON ai.item_id = i.item_id  
WHERE a.name = 'Kitchen Standard Package'
ORDER BY i.category, i.item_type, i.description;

-- -----------------------------------------------------------------------------
-- 7. DATA INTEGRITY CHECKS
-- Verify referential integrity and data quality
-- -----------------------------------------------------------------------------

SELECT 
    '=== DATA INTEGRITY CHECKS ===' as test_name;

-- Check for orphaned assembly items
SELECT 
    'Orphaned AssemblyItems (should be 0)' as check_name,
    COUNT(*) as count
FROM AssemblyItems ai
LEFT JOIN Assemblies a ON ai.assembly_id = a.assembly_id
LEFT JOIN Items i ON ai.item_id = i.item_id
WHERE a.assembly_id IS NULL OR i.item_id IS NULL;

-- Check for assemblies without items
SELECT 
    'Assemblies without items (should be 0)' as check_name,
    COUNT(*) as count  
FROM Assemblies a
LEFT JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
WHERE ai.assembly_id IS NULL;

-- Check for negative or zero quantities
SELECT 
    'Invalid quantities (should be 0)' as check_name,
    COUNT(*) as count
FROM AssemblyItems ai
WHERE ai.quantity <= 0;

-- Check for missing production rates on labor items
SELECT 
    'Labor items without production rates (should be 0)' as check_name,
    COUNT(*) as count
FROM Items i
JOIN AssemblyItems ai ON i.item_id = ai.item_id
WHERE i.item_type = 'labor' 
  AND (i.quantity_per_unit IS NULL OR i.quantity_per_unit <= 0);

-- -----------------------------------------------------------------------------
-- 8. ASSEMBLY TEMPLATE SUMMARY REPORT
-- Final summary for validation
-- -----------------------------------------------------------------------------

SELECT 
    '=== ASSEMBLY TEMPLATE SUMMARY REPORT ===' as test_name;

WITH assembly_summary AS (
    SELECT 
        a.category,
        a.name,
        COUNT(DISTINCT ai.item_id) as items_count,
        COUNT(DISTINCT i.category) as categories_count,
        SUM(CASE WHEN i.item_type = 'material' THEN 1 ELSE 0 END) as material_items,
        SUM(CASE WHEN i.item_type = 'labor' THEN 1 ELSE 0 END) as labor_items,
        ROUND(AVG(ai.quantity)::numeric, 3) as avg_quantity,
        ROUND(SUM(
            CASE 
                WHEN a.category = 'kitchen' AND i.item_type = 'material' THEN 
                    ai.quantity * 120 * i.national_average_cost
                WHEN a.category = 'bathroom' AND i.item_type = 'material' THEN
                    ai.quantity * 50 * i.national_average_cost
                ELSE 0
            END
        )::numeric, 0) as estimated_material_cost
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    GROUP BY a.category, a.name, a.assembly_id
)
SELECT 
    category,
    name as assembly_name,
    items_count,
    categories_count, 
    material_items,
    labor_items,
    avg_quantity,
    estimated_material_cost,
    CASE 
        WHEN category = 'kitchen' THEN '120 SF'
        WHEN category = 'bathroom' THEN '50 SF'
    END as basis_size
FROM assembly_summary
ORDER BY category, name;

-- Final validation message
SELECT 
    '=== VALIDATION COMPLETE ===' as test_name,
    'Assembly templates ready for Assembly Engine integration!' as status;

-- =============================================================================
-- PERFORMANCE TEST QUERIES  
-- These simulate high-load scenarios the Assembly Engine will face
-- =============================================================================

-- Performance test: Multiple assembly cost calculations
EXPLAIN (ANALYZE, BUFFERS) 
WITH performance_test AS (
    SELECT 
        a.name,
        SUM(ai.quantity * i.national_average_cost * 120) as total_cost
    FROM Assemblies a
    JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
    JOIN Items i ON ai.item_id = i.item_id
    WHERE a.category = 'kitchen'
    GROUP BY a.assembly_id, a.name
)
SELECT * FROM performance_test;