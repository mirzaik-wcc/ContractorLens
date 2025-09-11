-- Migration: V2 - Add Professional Estimate Tables
-- Objective: Establish the necessary database structure for Level 5 estimate granularity.
-- Created: 2025-09-10

-- Phase 1, Step 1.2: Implement New Granularity Tables

-- Trades table with CSI divisions for professional organization
CREATE TABLE Trades (
    trade_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    csi_division VARCHAR(10) NOT NULL,
    division_name VARCHAR(100) NOT NULL,
    trade_name VARCHAR(100) NOT NULL,
    sort_order INTEGER,
    typical_crew_size INTEGER,
    base_hourly_rate DECIMAL(6,2)
);

-- MaterialSpecifications for detailed product data
CREATE TABLE MaterialSpecifications (
    spec_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID REFERENCES Items(item_id),
    manufacturer VARCHAR(100),
    model_number VARCHAR(50),
    brand_name VARCHAR(100),
    color_finish VARCHAR(50),
    size_dimensions VARCHAR(100),
    weight DECIMAL(8,2),
    warranty_years INTEGER,
    energy_rating VARCHAR(20),
    compliance_codes TEXT[]
);

-- LaborTasks for detailed labor production rates and requirements
CREATE TABLE LaborTasks (
    task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID REFERENCES Items(item_id),
    task_name VARCHAR(200),
    task_description TEXT,
    base_production_rate DECIMAL(10,6),
    crew_size INTEGER DEFAULT 1,
    skill_level VARCHAR(20) CHECK (skill_level IN ('apprentice', 'journeyman', 'master')),
    setup_time_hours DECIMAL(4,2),
    cleanup_time_hours DECIMAL(4,2),
    difficulty_multiplier DECIMAL(3,2) DEFAULT 1.0
);

-- WasteFactors for material-specific waste percentages
CREATE TABLE WasteFactors (
    waste_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID REFERENCES Items(item_id),
    material_type VARCHAR(50),
    base_waste_percentage DECIMAL(5,2),
    cut_waste_percentage DECIMAL(5,2),
    breakage_percentage DECIMAL(5,2),
    pattern_match_percentage DECIMAL(5,2)
);

-- WorkSequences for future trade dependency logic
CREATE TABLE WorkSequences (
    sequence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    predecessor_trade_id UUID REFERENCES Trades(trade_id),
    successor_trade_id UUID REFERENCES Trades(trade_id),
    dependency_type VARCHAR(20) CHECK (dependency_type IN ('must_complete', 'can_overlap')),
    lag_days INTEGER DEFAULT 0
);

-- Phase 1, Step 1.3: Alter the Existing Items Table

ALTER TABLE Items ADD COLUMN trade_id UUID REFERENCES Trades(trade_id);
ALTER TABLE Items ADD COLUMN manufacturer VARCHAR(100);
ALTER TABLE Items ADD COLUMN model_number VARCHAR(50);
ALTER TABLE Items ADD COLUMN detailed_description TEXT;
ALTER TABLE Items ADD COLUMN installation_notes TEXT;

-- End of Migration V2
