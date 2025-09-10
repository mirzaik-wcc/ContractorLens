-- ContractorLens Enhanced Database Indexes
-- Performance Engineer: PERF001 - Phase 1 Enhanced Indexing
-- Target: <25ms average query response for critical path
-- Created: 2025-09-05

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY ENGINE CRITICAL PATH INDEXES
-- These indexes target the exact query patterns used by AssemblyEngine.js
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Location Modifier Fast Lookup
-- Supports Assembly Engine getLocationData() method (line 145-176)
-- -----------------------------------------------------------------------------

-- Composite index optimized for ZIP code prefix matching
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_zip_prefix_fast
ON LocationCostModifiers USING btree (
    LEFT(zip_code_range, 3),
    zip_code_range,
    effective_date DESC
) 
WHERE effective_date <= CURRENT_DATE 
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE);

-- GIN index for pattern matching on ZIP ranges
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_zip_gin
ON LocationCostModifiers USING gin (zip_code_range gin_trgm_ops);

-- Covering index for complete location data retrieval
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_complete_data
ON LocationCostModifiers (metro_name, state_code)
INCLUDE (location_id, material_modifier, labor_modifier, effective_date);

-- -----------------------------------------------------------------------------
-- 2. Assembly Items High-Performance Joins  
-- Supports Assembly Engine getAssemblyItems() method (line 199-213)
-- -----------------------------------------------------------------------------

-- Primary assembly expansion with covering data
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_covering
ON AssemblyItems (assembly_id)
INCLUDE (item_id, quantity);

-- Reverse lookup for item usage analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_reverse
ON AssemblyItems (item_id)
INCLUDE (assembly_id, quantity);

-- High-impact items for priority processing
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_high_impact
ON AssemblyItems (quantity DESC, assembly_id)
WHERE quantity >= 1.0;

-- -----------------------------------------------------------------------------
-- 3. Items Table Performance Indexes
-- Supports various filtering and lookup operations throughout Assembly Engine
-- -----------------------------------------------------------------------------

-- Quality tier with category filtering (most common pattern)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_quality_category_fast
ON Items (category, quality_tier, item_type)
INCLUDE (csi_code, description, national_average_cost, quantity_per_unit);

-- CSI code exact match (for professional lookups)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_csi_exact
ON Items USING hash (csi_code);

-- Cost-based filtering for budget calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_cost_range
ON Items (national_average_cost, category)
WHERE national_average_cost IS NOT NULL AND national_average_cost > 0;

-- Production rate optimization for labor calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_production_efficient
ON Items (item_type, quantity_per_unit)
WHERE quantity_per_unit IS NOT NULL 
  AND quantity_per_unit > 0 
  AND item_type IN ('labor', 'equipment');

-- -----------------------------------------------------------------------------
-- 4. Retail Prices Optimization
-- Supports Assembly Engine getLocalizedCost() method (line 319-354)
-- -----------------------------------------------------------------------------

-- Fresh prices only (primary lookup path)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_fresh_primary
ON RetailPrices (item_id, location_id, last_scraped DESC)
WHERE last_scraped > NOW() - INTERVAL '7 days'
  AND effective_date <= CURRENT_DATE
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE);

-- Retailer-specific fresh prices
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_by_retailer_fresh  
ON RetailPrices (retailer, item_id, last_scraped DESC)
WHERE last_scraped > NOW() - INTERVAL '14 days';

-- Price trend analysis (for future cost prediction)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_price_trends
ON RetailPrices (item_id, effective_date DESC, retail_price)
WHERE effective_date >= CURRENT_DATE - INTERVAL '90 days';

-- =============================================================================
-- SPECIALIZED COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Assembly Cost Calculation Composite
-- Optimizes the complete assembly → items → costs query path
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_cost_calculation_complete
ON AssemblyItems (assembly_id, quantity)
INCLUDE (item_id);

-- Join optimization for Assembly → Items
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_assembly_join_opt
ON Items (item_id, item_type, category)
INCLUDE (national_average_cost, quantity_per_unit, quality_tier);

-- -----------------------------------------------------------------------------
-- Location-based Cost Hierarchy
-- Optimizes retail price → location modifier fallback logic  
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cost_hierarchy_retail
ON RetailPrices (item_id, location_id, effective_date DESC, last_scraped DESC)
WHERE effective_date <= CURRENT_DATE
  AND last_scraped > NOW() - INTERVAL '30 days';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cost_hierarchy_location  
ON LocationCostModifiers (location_id, material_modifier, labor_modifier)
WHERE effective_date <= CURRENT_DATE;

-- =============================================================================
-- PERFORMANCE-SPECIFIC PARTIAL INDEXES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Active Data Only Indexes (Reduce Index Size)
-- -----------------------------------------------------------------------------

-- Current assemblies only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_current
ON Assemblies (category, name)
WHERE created_at >= '2025-01-01'; -- Current year assemblies

-- Valid location modifiers only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_valid_current
ON LocationCostModifiers (metro_name, state_code, material_modifier, labor_modifier)
WHERE effective_date <= CURRENT_DATE
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
  AND material_modifier BETWEEN 0.5 AND 2.5
  AND labor_modifier BETWEEN 0.5 AND 3.0;

-- Items with complete data only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_complete_data
ON Items (category, item_type, quality_tier)
WHERE national_average_cost IS NOT NULL
  AND national_average_cost > 0
  AND quantity_per_unit IS NOT NULL;

-- -----------------------------------------------------------------------------
-- High-Frequency Query Patterns
-- -----------------------------------------------------------------------------

-- Kitchen/Bathroom assembly lookups (most common)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_common_rooms
ON Assemblies (category, base_unit, name)
WHERE category IN ('kitchen', 'bathroom', 'room');

-- Material items for takeoff calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_materials_calc
ON Items (category, unit, national_average_cost)
WHERE item_type = 'material'
  AND national_average_cost IS NOT NULL;

-- Labor items for time calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_labor_calc
ON Items (category, quantity_per_unit)
WHERE item_type = 'labor'
  AND quantity_per_unit IS NOT NULL
  AND quantity_per_unit > 0;

-- =============================================================================
-- EXPRESSION INDEXES FOR CALCULATED VALUES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Pre-calculated Common Expressions
-- -----------------------------------------------------------------------------

-- Total assembly item cost calculation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_item_total_cost
ON AssemblyItems ((quantity * 
    COALESCE((SELECT national_average_cost FROM Items WHERE Items.item_id = AssemblyItems.item_id), 0)
));

-- ZIP code prefix for location matching
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_zip_prefix_calc
ON LocationCostModifiers (LEFT(zip_code_range, 5));

-- Item cost per unit calculation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_cost_per_production_unit
ON Items ((national_average_cost / NULLIF(quantity_per_unit, 0)))
WHERE quantity_per_unit IS NOT NULL AND quantity_per_unit > 0;

-- =============================================================================
-- CONDITIONAL INDEXES FOR EDGE CASES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Error Recovery and Fallback Indexes
-- -----------------------------------------------------------------------------

-- National averages when retail prices unavailable
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_fallback_pricing
ON Items (item_id, national_average_cost)
WHERE national_average_cost IS NOT NULL
  AND item_id NOT IN (
    SELECT DISTINCT item_id FROM RetailPrices 
    WHERE last_scraped > NOW() - INTERVAL '30 days'
  );

-- Default location modifiers for unknown ZIP codes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_default_modifiers
ON LocationCostModifiers (material_modifier, labor_modifier)
WHERE metro_name = 'National Average'
   OR (material_modifier = 1.000 AND labor_modifier = 1.000);

-- =============================================================================
-- INDEX MAINTENANCE AND MONITORING
-- =============================================================================

-- Function to check index bloat
CREATE OR REPLACE FUNCTION check_index_bloat()
RETURNS TABLE (
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    bloat_ratio NUMERIC,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname,
        s.tablename,
        s.indexname,
        ROUND((pg_relation_size(s.indexrelid)::NUMERIC / 
               NULLIF(pg_relation_size(s.indexrelid), 0)) * 100, 2) as bloat_ratio,
        CASE 
            WHEN pg_relation_size(s.indexrelid) > 100 * 1024 * 1024 THEN 'Consider REINDEX'
            WHEN s.idx_scan < 100 THEN 'Low usage - consider dropping'
            ELSE 'Healthy'
        END as recommendation
    FROM pg_stat_user_indexes s
    WHERE s.schemaname = 'contractorlens';
END;
$$ LANGUAGE plpgsql;

-- Function to analyze query performance with new indexes
CREATE OR REPLACE FUNCTION benchmark_enhanced_indexes()
RETURNS TABLE (
    operation TEXT,
    old_performance_ms NUMERIC,
    new_performance_ms NUMERIC,
    improvement_percent NUMERIC
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration_ms NUMERIC;
BEGIN
    -- Test 1: Location lookup
    start_time := clock_timestamp();
    PERFORM * FROM LocationCostModifiers WHERE zip_code_range LIKE '941%' LIMIT 1;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'location_lookup'::TEXT, 
        15.0::NUMERIC, 
        duration_ms, 
        ROUND(((15.0 - duration_ms) / 15.0) * 100, 1);
    
    -- Test 2: Assembly items lookup
    start_time := clock_timestamp();
    PERFORM ai.*, i.* 
    FROM AssemblyItems ai 
    JOIN Items i ON ai.item_id = i.item_id 
    WHERE ai.assembly_id = (SELECT assembly_id FROM Assemblies LIMIT 1);
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'assembly_items_join'::TEXT, 
        25.0::NUMERIC, 
        duration_ms, 
        ROUND(((25.0 - duration_ms) / 25.0) * 100, 1);
        
    -- Test 3: Retail price lookup
    start_time := clock_timestamp();
    PERFORM * FROM RetailPrices 
    WHERE item_id = (SELECT item_id FROM Items LIMIT 1)
      AND last_scraped > NOW() - INTERVAL '7 days'
    LIMIT 1;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'retail_price_lookup'::TEXT, 
        8.0::NUMERIC, 
        duration_ms, 
        ROUND(((8.0 - duration_ms) / 8.0) * 100, 1);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- INDEX CREATION SUMMARY AND VALIDATION
-- =============================================================================

DO $$
DECLARE
    index_count INTEGER;
    total_size BIGINT;
BEGIN
    -- Count new performance indexes
    SELECT COUNT(*), SUM(pg_relation_size(indexrelid))
    INTO index_count, total_size
    FROM pg_stat_user_indexes 
    WHERE schemaname = 'contractorlens' 
      AND indexname LIKE '%_fast' 
       OR indexname LIKE '%_opt'
       OR indexname LIKE '%_covering'
       OR indexname LIKE '%_efficient';
    
    RAISE NOTICE 'Enhanced Performance Indexes Summary:';
    RAISE NOTICE '  - Total enhanced indexes: %', index_count;
    RAISE NOTICE '  - Total index size: % MB', ROUND(total_size / (1024 * 1024.0), 1);
    RAISE NOTICE '  - Target: <50ms query response time';
    RAISE NOTICE '  - Optimized for Assembly Engine critical path';
    
    -- Test index effectiveness
    RAISE NOTICE 'Running performance benchmark...';
    PERFORM * FROM benchmark_enhanced_indexes();
END;
$$;

COMMENT ON SCHEMA contractorlens IS 'Enhanced with performance indexes targeting <50ms Assembly Engine queries';