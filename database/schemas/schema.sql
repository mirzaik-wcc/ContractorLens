-- ContractorLens PostgreSQL Schema
-- Database Engineer: DB001 - Create PostgreSQL Schema
-- Version: 1.0
-- Created: 2025-09-03

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schema namespace
CREATE SCHEMA IF NOT EXISTS contractorlens;
SET search_path TO contractorlens, public;

-- =============================================================================
-- CORE TABLES: Items, Assemblies, Location Modifiers, Retail Prices
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Items Table: Core materials and labor with CSI codes
-- This is the foundation of all cost calculations
-- Contains production rates critical for Assembly Engine deterministic calculations
-- -----------------------------------------------------------------------------
CREATE TABLE Items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- CSI classification system
    csi_code VARCHAR(20) NOT NULL,
    description TEXT NOT NULL,
    unit VARCHAR(20) NOT NULL, -- SF, LF, EA, etc.
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50),
    
    -- Production rates (CRITICAL for Assembly Engine)
    -- For materials: quantity_per_unit = amount needed per unit (e.g., 1.05 SF drywall per SF wall)
    -- For labor: quantity_per_unit = hours per unit (e.g., 0.016 hours/SF for drywall installation)
    quantity_per_unit DECIMAL(10,6),
    
    -- Quality tiers for finish levels (good/better/best)
    quality_tier VARCHAR(20) CHECK (quality_tier IN ('good', 'better', 'best')),
    
    -- National baseline costs (before location modifiers)
    national_average_cost DECIMAL(10,2),
    
    -- Item type classification
    item_type VARCHAR(20) NOT NULL CHECK (item_type IN ('material', 'labor', 'equipment')),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT items_csi_code_check CHECK (csi_code ~ '^[0-9]{2} [0-9]{2} [0-9]{2}$'),
    CONSTRAINT items_unit_check CHECK (unit IN ('SF', 'LF', 'EA', 'HR', 'CY', 'SY', 'CF', 'LB', 'GAL', 'TON'))
);

-- Comments for Items table
COMMENT ON TABLE Items IS 'Core materials and labor items with CSI codes and production rates';
COMMENT ON COLUMN Items.quantity_per_unit IS 'Production rate: hours per unit for labor, quantity per unit for materials';
COMMENT ON COLUMN Items.quality_tier IS 'Finish level: good/better/best for user preference calculations';
COMMENT ON COLUMN Items.national_average_cost IS 'Baseline cost before location modifiers are applied';

-- -----------------------------------------------------------------------------
-- Assemblies Table: Pre-defined combinations (kitchen, bathroom, etc.)
-- These are "recipes" that combine multiple items for common construction activities
-- -----------------------------------------------------------------------------
CREATE TABLE Assemblies (
    assembly_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL, -- 'kitchen', 'bathroom', 'room', etc.
    
    -- Optional CSI code for the assembly itself
    csi_code VARCHAR(20),
    
    -- Default unit for assembly calculations
    base_unit VARCHAR(20) NOT NULL DEFAULT 'SF',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT assemblies_category_check CHECK (category IN ('kitchen', 'bathroom', 'room', 'exterior', 'flooring', 'wall', 'ceiling'))
);

COMMENT ON TABLE Assemblies IS 'Pre-defined combinations of items for common construction activities';
COMMENT ON COLUMN Assemblies.base_unit IS 'Primary unit of measure for this assembly (SF, LF, EA)';

-- -----------------------------------------------------------------------------
-- AssemblyItems Junction Table: Many-to-many relationship between Assemblies and Items
-- This is where the "recipe" is defined - what items go into each assembly and in what quantities
-- -----------------------------------------------------------------------------
CREATE TABLE AssemblyItems (
    assembly_id UUID NOT NULL REFERENCES Assemblies(assembly_id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES Items(item_id) ON DELETE CASCADE,
    
    -- Quantity of this item needed per unit of assembly
    -- e.g., 1.05 SF of drywall per 1 SF of wall assembly (waste factor included)
    quantity DECIMAL(10,4) NOT NULL,
    
    -- Optional notes about this relationship
    notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Primary key on the relationship
    PRIMARY KEY (assembly_id, item_id),
    
    -- Constraints
    CONSTRAINT assembly_items_quantity_positive CHECK (quantity > 0)
);

COMMENT ON TABLE AssemblyItems IS 'Junction table defining which items are included in each assembly and quantities';
COMMENT ON COLUMN AssemblyItems.quantity IS 'Quantity of item needed per unit of assembly (includes waste factors)';

-- -----------------------------------------------------------------------------
-- LocationCostModifiers Table: CCI multipliers by geographic region
-- Used to adjust national_average_cost based on local market conditions
-- Stores MULTIPLIERS, not absolute prices
-- -----------------------------------------------------------------------------
CREATE TABLE LocationCostModifiers (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Geographic identifiers
    metro_name VARCHAR(100) NOT NULL,
    state_code CHAR(2) NOT NULL,
    zip_code_range VARCHAR(20), -- Can be specific ZIP or range like "10001-10099"
    
    -- City Cost Index multipliers (relative to national average = 1.000)
    material_modifier DECIMAL(4,3) NOT NULL DEFAULT 1.000,
    labor_modifier DECIMAL(4,3) NOT NULL DEFAULT 1.000,
    
    -- Effective date range for these modifiers
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT location_modifiers_positive CHECK (material_modifier > 0 AND labor_modifier > 0),
    CONSTRAINT location_modifiers_reasonable CHECK (material_modifier BETWEEN 0.5 AND 2.5 AND labor_modifier BETWEEN 0.5 AND 3.0),
    CONSTRAINT location_state_code_check CHECK (state_code ~ '^[A-Z]{2}$')
);

COMMENT ON TABLE LocationCostModifiers IS 'Geographic cost multipliers based on City Cost Index data';
COMMENT ON COLUMN LocationCostModifiers.material_modifier IS 'Multiplier applied to material costs (1.000 = national average)';
COMMENT ON COLUMN LocationCostModifiers.labor_modifier IS 'Multiplier applied to labor costs (1.000 = national average)';

-- -----------------------------------------------------------------------------
-- RetailPrices Table: Localized pricing data (overrides national_average when available)
-- Real-time scraped prices from retailers like Home Depot, Lowes
-- Takes precedence over national_average in cost hierarchy
-- -----------------------------------------------------------------------------
CREATE TABLE RetailPrices (
    price_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES Items(item_id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES LocationCostModifiers(location_id) ON DELETE CASCADE,
    
    -- Actual retail price
    retail_price DECIMAL(10,2) NOT NULL,
    
    -- Price validity period
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    
    -- Source information
    retailer VARCHAR(50) NOT NULL, -- 'Home Depot', 'Lowes', 'Menards', etc.
    product_sku VARCHAR(100),
    
    -- Data freshness tracking
    last_scraped TIMESTAMP DEFAULT NOW(),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT retail_prices_positive CHECK (retail_price > 0),
    CONSTRAINT retail_prices_dates CHECK (expiry_date IS NULL OR expiry_date > effective_date),
    CONSTRAINT retail_prices_retailer_check CHECK (retailer IN ('Home Depot', 'Lowes', 'Menards', 'Other'))
);

COMMENT ON TABLE RetailPrices IS 'Real-time retail prices that override national averages in cost calculations';
COMMENT ON COLUMN RetailPrices.retail_price IS 'Current retail price for this item at this location';
COMMENT ON COLUMN RetailPrices.last_scraped IS 'When this price was last updated from retailer APIs';

-- =============================================================================
-- SUPPORTING TABLES: User preferences, tracking, etc.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- UserFinishPreferences Table: User's quality tier preferences by category
-- Allows users to set default finish levels (good/better/best) for different categories
-- -----------------------------------------------------------------------------
CREATE TABLE UserFinishPreferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL, -- External user identifier
    
    -- Category for this preference
    category VARCHAR(50) NOT NULL,
    
    -- Preferred quality tier for this category
    preferred_quality_tier VARCHAR(20) NOT NULL CHECK (preferred_quality_tier IN ('good', 'better', 'best')),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Unique constraint: one preference per user per category
    UNIQUE (user_id, category)
);

COMMENT ON TABLE UserFinishPreferences IS 'User preferences for quality tiers by item category';

-- -----------------------------------------------------------------------------
-- Projects Table: Container for user project estimates
-- Links estimates to specific projects and locations
-- -----------------------------------------------------------------------------
CREATE TABLE Projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(255) NOT NULL,
    
    -- Project details
    project_name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Location for cost calculations
    location_id UUID REFERENCES LocationCostModifiers(location_id),
    address TEXT,
    zip_code VARCHAR(10),
    
    -- Project status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE Projects IS 'User projects containing multiple estimates and calculations';

-- =============================================================================
-- INDEXES AND CONSTRAINTS
-- =============================================================================

-- Items table indexes
CREATE INDEX idx_items_csi_code ON Items(csi_code);
CREATE INDEX idx_items_category ON Items(category);
CREATE INDEX idx_items_quality_tier ON Items(quality_tier);
CREATE INDEX idx_items_type ON Items(item_type);
CREATE INDEX idx_items_category_quality ON Items(category, quality_tier);

-- Assemblies table indexes
CREATE INDEX idx_assemblies_category ON Assemblies(category);
CREATE INDEX idx_assemblies_csi_code ON Assemblies(csi_code);

-- AssemblyItems table indexes
CREATE INDEX idx_assembly_items_assembly_id ON AssemblyItems(assembly_id);
CREATE INDEX idx_assembly_items_item_id ON AssemblyItems(item_id);

-- LocationCostModifiers table indexes
CREATE INDEX idx_location_metro_state ON LocationCostModifiers(metro_name, state_code);
CREATE INDEX idx_location_effective_date ON LocationCostModifiers(effective_date);
CREATE INDEX idx_location_zip_range ON LocationCostModifiers(zip_code_range);

-- RetailPrices table indexes
CREATE INDEX idx_retail_prices_item_location ON RetailPrices(item_id, location_id);
CREATE INDEX idx_retail_prices_effective_date ON RetailPrices(effective_date);
CREATE INDEX idx_retail_prices_retailer ON RetailPrices(retailer);
CREATE INDEX idx_retail_prices_freshness ON RetailPrices(last_scraped);

-- UserFinishPreferences table indexes
CREATE INDEX idx_user_preferences_user_id ON UserFinishPreferences(user_id);

-- Projects table indexes
CREATE INDEX idx_projects_user_id ON Projects(user_id);
CREATE INDEX idx_projects_location_id ON Projects(location_id);
CREATE INDEX idx_projects_status ON Projects(status);

-- =============================================================================
-- FUNCTIONS AND TRIGGERS
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to all relevant tables
CREATE TRIGGER update_items_updated_at BEFORE UPDATE ON Items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assemblies_updated_at BEFORE UPDATE ON Assemblies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_location_modifiers_updated_at BEFORE UPDATE ON LocationCostModifiers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_retail_prices_updated_at BEFORE UPDATE ON RetailPrices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON UserFinishPreferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON Projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- COST CALCULATION HELPER FUNCTION
-- =============================================================================

-- Function to get localized cost for an item
-- Implements the cost hierarchy: RetailPrices → national_average × location_modifier
CREATE OR REPLACE FUNCTION get_localized_item_cost(
    p_item_id UUID,
    p_location_id UUID
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    retail_price DECIMAL(10,2);
    base_cost DECIMAL(10,2);
    modifier DECIMAL(4,3);
    item_type_val VARCHAR(20);
    final_cost DECIMAL(10,2);
BEGIN
    -- First, check for current retail price
    SELECT rp.retail_price INTO retail_price
    FROM RetailPrices rp
    WHERE rp.item_id = p_item_id
      AND rp.location_id = p_location_id
      AND rp.effective_date <= CURRENT_DATE
      AND (rp.expiry_date IS NULL OR rp.expiry_date > CURRENT_DATE)
      AND rp.last_scraped > NOW() - INTERVAL '7 days'
    ORDER BY rp.last_scraped DESC
    LIMIT 1;
    
    -- If retail price found, return it
    IF retail_price IS NOT NULL THEN
        RETURN retail_price;
    END IF;
    
    -- Otherwise, use national average with location modifier
    SELECT i.national_average_cost, i.item_type
    INTO base_cost, item_type_val
    FROM Items i
    WHERE i.item_id = p_item_id;
    
    -- Get appropriate modifier based on item type
    SELECT CASE 
        WHEN item_type_val = 'material' THEN lcm.material_modifier
        WHEN item_type_val = 'labor' THEN lcm.labor_modifier
        ELSE 1.000
    END INTO modifier
    FROM LocationCostModifiers lcm
    WHERE lcm.location_id = p_location_id
      AND lcm.effective_date <= CURRENT_DATE
      AND (lcm.expiry_date IS NULL OR lcm.expiry_date > CURRENT_DATE)
    ORDER BY lcm.effective_date DESC
    LIMIT 1;
    
    -- Calculate final cost
    final_cost := COALESCE(base_cost, 0) * COALESCE(modifier, 1.000);
    
    RETURN final_cost;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_localized_item_cost IS 'Calculates localized cost using cost hierarchy: retail prices override national average with location modifiers';

-- =============================================================================
-- SCHEMA VALIDATION
-- =============================================================================

-- Verify all tables were created successfully
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'contractorlens'
      AND table_type = 'BASE TABLE';
    
    IF table_count < 7 THEN
        RAISE EXCEPTION 'Schema creation incomplete. Expected 7 tables, found %', table_count;
    END IF;
    
    RAISE NOTICE 'ContractorLens schema created successfully with % tables', table_count;
END;
$$;