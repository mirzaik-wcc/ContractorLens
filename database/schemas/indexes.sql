-- ContractorLens PostgreSQL Performance Indexes
-- Database Engineer: DB001 - Performance indexes for Assembly Engine
-- Version: 1.0
-- Created: 2025-09-03

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY ENGINE PERFORMANCE INDEXES
-- These indexes are optimized for the deterministic cost calculation queries
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Items Table Indexes - Core lookup performance
-- -----------------------------------------------------------------------------

-- Primary CSI code lookups (frequently used by Assembly Engine)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_csi_code_btree 
ON Items USING btree (csi_code);

-- Category-based filtering with quality tier (finish level selections)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_category_quality_tier 
ON Items USING btree (category, quality_tier);

-- Item type filtering (material vs labor vs equipment)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_type_category 
ON Items USING btree (item_type, category);

-- Cost-based sorting for budget calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_national_cost 
ON Items USING btree (national_average_cost) 
WHERE national_average_cost IS NOT NULL;

-- Production rate lookups (critical for Assembly Engine calculations)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_production_rates 
ON Items USING btree (quantity_per_unit) 
WHERE quantity_per_unit IS NOT NULL;

-- Composite index for common Assembly Engine queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_engine_lookup 
ON Items USING btree (category, item_type, quality_tier, csi_code);

-- -----------------------------------------------------------------------------
-- Assemblies Table Indexes - Assembly lookup performance
-- -----------------------------------------------------------------------------

-- Category-based assembly lookups (kitchen, bathroom, etc.)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_category_name 
ON Assemblies USING btree (category, name);

-- CSI-based assembly organization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_csi_category 
ON Assemblies USING btree (csi_code, category) 
WHERE csi_code IS NOT NULL;

-- Base unit filtering for unit conversion logic
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_base_unit 
ON Assemblies USING btree (base_unit);

-- -----------------------------------------------------------------------------
-- AssemblyItems Junction Table Indexes - Critical for Assembly Engine
-- -----------------------------------------------------------------------------

-- Primary assembly expansion queries (get all items for an assembly)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_assembly_lookup 
ON AssemblyItems USING btree (assembly_id, quantity DESC);

-- Reverse lookup (which assemblies use this item)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_item_lookup 
ON AssemblyItems USING btree (item_id, assembly_id);

-- Quantity-based filtering for high-impact items
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_high_quantity 
ON AssemblyItems USING btree (quantity DESC) 
WHERE quantity > 1.0;

-- Composite index for join performance in Assembly Engine calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_items_full_join 
ON AssemblyItems USING btree (assembly_id, item_id, quantity);

-- -----------------------------------------------------------------------------
-- LocationCostModifiers Table Indexes - Geographic cost calculations
-- -----------------------------------------------------------------------------

-- Primary location lookup by metro and state
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_metro_state_lookup 
ON LocationCostModifiers USING btree (metro_name, state_code);

-- ZIP code range lookups (supports both exact and range queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_zip_ranges 
ON LocationCostModifiers USING btree (zip_code_range) 
WHERE zip_code_range IS NOT NULL;

-- Current modifier lookups (filtering by effective date)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_current_modifiers 
ON LocationCostModifiers USING btree (effective_date, expiry_date);

-- Material vs labor modifier separation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_material_modifiers 
ON LocationCostModifiers USING btree (material_modifier) 
WHERE material_modifier != 1.000;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_labor_modifiers 
ON LocationCostModifiers USING btree (labor_modifier) 
WHERE labor_modifier != 1.000;

-- Composite index for the cost calculation function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_cost_calculation 
ON LocationCostModifiers USING btree (location_id, effective_date DESC, expiry_date);

-- -----------------------------------------------------------------------------
-- RetailPrices Table Indexes - Real-time pricing lookups
-- -----------------------------------------------------------------------------

-- Primary retail price lookup (item + location)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_prices_item_location_current 
ON RetailPrices USING btree (item_id, location_id, effective_date DESC);

-- Data freshness filtering (prefer recent prices)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_prices_freshness 
ON RetailPrices USING btree (last_scraped DESC, item_id) 
WHERE last_scraped > NOW() - INTERVAL '7 days';

-- Retailer-specific lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_prices_retailer_fresh 
ON RetailPrices USING btree (retailer, last_scraped DESC);

-- Price expiry management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_prices_expiry_cleanup 
ON RetailPrices USING btree (expiry_date) 
WHERE expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE;

-- Composite index for the cost hierarchy logic
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_prices_hierarchy 
ON RetailPrices USING btree (item_id, location_id, effective_date DESC, last_scraped DESC) 
WHERE effective_date <= CURRENT_DATE 
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE);

-- -----------------------------------------------------------------------------
-- UserFinishPreferences Table Indexes - User preference queries
-- -----------------------------------------------------------------------------

-- User preference lookups by category
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_preferences_user_category 
ON UserFinishPreferences USING btree (user_id, category);

-- Quality tier distribution analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_preferences_quality_stats 
ON UserFinishPreferences USING btree (preferred_quality_tier, category);

-- -----------------------------------------------------------------------------
-- Projects Table Indexes - Project management queries
-- -----------------------------------------------------------------------------

-- User's active projects
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projects_user_active 
ON Projects USING btree (user_id, status, created_at DESC) 
WHERE status = 'active';

-- Location-based project queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projects_location_lookup 
ON Projects USING btree (location_id, status);

-- ZIP code geographic queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projects_zip_code 
ON Projects USING btree (zip_code) 
WHERE zip_code IS NOT NULL;

-- =============================================================================
-- SPECIALIZED INDEXES FOR COMMON QUERY PATTERNS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Assembly Engine Cost Calculation Pattern
-- Optimizes the most common query: get all items for assembly with costs
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assembly_cost_calculation 
ON AssemblyItems USING btree (assembly_id) 
INCLUDE (item_id, quantity);

-- Supports queries like:
-- SELECT ai.quantity, i.national_average_cost, i.quantity_per_unit, i.item_type
-- FROM AssemblyItems ai
-- JOIN Items i ON ai.item_id = i.item_id
-- WHERE ai.assembly_id = ?

-- -----------------------------------------------------------------------------
-- Location-based Cost Lookup Pattern
-- Optimizes geographic cost calculations
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_cost_lookup 
ON LocationCostModifiers USING btree (metro_name, state_code, effective_date DESC) 
INCLUDE (material_modifier, labor_modifier);

-- -----------------------------------------------------------------------------
-- Retail Price Override Pattern
-- Optimizes the cost hierarchy check: retail prices before national average
-- -----------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_retail_override_lookup 
ON RetailPrices USING btree (item_id, location_id, last_scraped DESC) 
INCLUDE (retail_price, effective_date, expiry_date)
WHERE last_scraped > NOW() - INTERVAL '7 days';

-- =============================================================================
-- PARTIAL INDEXES FOR SPECIFIC CONDITIONS
-- =============================================================================

-- Only index items with production rates (performance optimization)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_with_production_rates 
ON Items USING btree (item_type, category) 
WHERE quantity_per_unit IS NOT NULL;

-- Only index current location modifiers (reduces index size)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_current_location_modifiers 
ON LocationCostModifiers USING btree (metro_name, state_code, material_modifier, labor_modifier) 
WHERE effective_date <= CURRENT_DATE 
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE);

-- Only index fresh retail prices (reduces index maintenance)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fresh_retail_prices 
ON RetailPrices USING btree (item_id, location_id, retail_price) 
WHERE last_scraped > NOW() - INTERVAL '30 days' 
  AND effective_date <= CURRENT_DATE;

-- =============================================================================
-- TEXT SEARCH INDEXES (for future search functionality)
-- =============================================================================

-- Full-text search on item descriptions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_items_description_fts 
ON Items USING gin(to_tsvector('english', description));

-- Assembly name and description search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assemblies_search_fts 
ON Assemblies USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- =============================================================================
-- INDEX MAINTENANCE AND MONITORING
-- =============================================================================

-- Create function to monitor index usage
CREATE OR REPLACE FUNCTION get_unused_indexes()
RETURNS TABLE (
    schemaname text,
    tablename text,
    indexname text,
    index_size text,
    index_scans bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname,
        s.tablename,
        s.indexname,
        pg_size_pretty(pg_relation_size(s.indexrelid)) as index_size,
        s.idx_scan as index_scans
    FROM pg_stat_user_indexes s
    JOIN pg_index i ON s.indexrelid = i.indexrelid
    WHERE s.schemaname = 'contractorlens'
      AND s.idx_scan < 10  -- Less than 10 scans since last stats reset
      AND NOT i.indisunique  -- Exclude unique indexes
      AND NOT i.indisprimary  -- Exclude primary keys
    ORDER BY s.idx_scan, pg_relation_size(s.indexrelid) DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_unused_indexes IS 'Monitor index usage to identify unused indexes for cleanup';

-- Create function to get index hit ratios
CREATE OR REPLACE FUNCTION get_index_hit_ratio()
RETURNS TABLE (
    schemaname text,
    tablename text,
    cache_hit_ratio numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname,
        s.relname as tablename,
        ROUND(
            (sum(s.idx_blks_hit) * 100.0) / 
            NULLIF(sum(s.idx_blks_hit + s.idx_blks_read), 0), 2
        ) as cache_hit_ratio
    FROM pg_statio_user_indexes s
    WHERE s.schemaname = 'contractorlens'
    GROUP BY s.schemaname, s.relname
    ORDER BY cache_hit_ratio DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_index_hit_ratio IS 'Monitor index cache hit ratios for performance tuning';

-- =============================================================================
-- INDEX CREATION SUMMARY
-- =============================================================================

DO $$
DECLARE
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE schemaname = 'contractorlens'
      AND indexname LIKE 'idx_%';
    
    RAISE NOTICE 'ContractorLens performance indexes created successfully. Total indexes: %', index_count;
    RAISE NOTICE 'Indexes optimized for Assembly Engine cost calculations and geographic lookups.';
END;
$$;