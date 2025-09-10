-- ContractorLens Items Catalog
-- Database Engineer: DB002 - Comprehensive material and labor items
-- Version: 1.0
-- Created: 2025-09-03

SET search_path TO contractorlens, public;

-- =============================================================================
-- KITCHEN & BATHROOM MATERIALS AND LABOR CATALOG
-- Real CSI codes, production rates, and market pricing by quality tier
-- =============================================================================

-- Clear existing items for clean seed (development only)
-- DELETE FROM Items; -- Uncomment for development reseeding

-- -----------------------------------------------------------------------------
-- FLOORING MATERIALS (CSI Division 09-60)
-- Production rates: Material installation hours per SF
-- -----------------------------------------------------------------------------

-- Kitchen Flooring Options
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier: Basic, functional options
  ('09 65 00', 'Luxury Vinyl Plank Flooring', 'SF', 'flooring', 'kitchen', 0.020, 'good', 'labor', 3.50),
  ('09 65 01', 'LVP Material - Good Grade', 'SF', 'flooring', 'kitchen', 1.05, 'good', 'material', 4.20),
  
  -- Better Tier: Mid-range quality
  ('09 30 13', 'Ceramic Tile Flooring Installation', 'SF', 'flooring', 'kitchen', 0.035, 'better', 'labor', 4.25),
  ('09 30 14', 'Ceramic Tile Material - Better Grade', 'SF', 'flooring', 'kitchen', 1.08, 'better', 'material', 8.50),
  
  -- Best Tier: Premium options
  ('09 64 00', 'Engineered Hardwood Installation', 'SF', 'flooring', 'kitchen', 0.045, 'best', 'labor', 5.50),
  ('09 64 01', 'Engineered Hardwood Material - Premium', 'SF', 'flooring', 'kitchen', 1.10, 'best', 'material', 11.75);

-- Bathroom Flooring Options
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('09 30 23', 'Basic Ceramic Tile Installation', 'SF', 'flooring', 'bathroom', 0.040, 'good', 'labor', 4.00),
  ('09 30 24', 'Basic Ceramic Tile Material', 'SF', 'flooring', 'bathroom', 1.10, 'good', 'material', 6.50),
  
  -- Better Tier
  ('09 30 33', 'Porcelain Tile Installation', 'SF', 'flooring', 'bathroom', 0.045, 'better', 'labor', 4.75),
  ('09 30 34', 'Porcelain Tile Material - Better', 'SF', 'flooring', 'bathroom', 1.12, 'better', 'material', 12.50),
  
  -- Best Tier
  ('09 30 43', 'Natural Stone Tile Installation', 'SF', 'flooring', 'bathroom', 0.055, 'best', 'labor', 6.25),
  ('09 30 44', 'Natural Stone Tile Material - Premium', 'SF', 'flooring', 'bathroom', 1.15, 'best', 'material', 22.00);

-- -----------------------------------------------------------------------------
-- CABINET SYSTEMS (CSI Division 06-40)
-- Production rates: Installation hours per linear foot
-- -----------------------------------------------------------------------------

-- Kitchen Cabinets
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier: Stock cabinets
  ('06 40 10', 'Stock Cabinet Installation', 'LF', 'cabinets', 'kitchen', 2.5, 'good', 'labor', 85.00),
  ('06 40 11', 'Stock Kitchen Cabinets', 'LF', 'cabinets', 'kitchen', 1.0, 'good', 'material', 180.00),
  
  -- Better Tier: Semi-custom
  ('06 40 20', 'Semi-Custom Cabinet Installation', 'LF', 'cabinets', 'kitchen', 3.2, 'better', 'labor', 95.00),
  ('06 40 21', 'Semi-Custom Kitchen Cabinets', 'LF', 'cabinets', 'kitchen', 1.0, 'better', 'material', 320.00),
  
  -- Best Tier: Full custom
  ('06 40 30', 'Custom Cabinet Installation', 'LF', 'cabinets', 'kitchen', 4.0, 'best', 'labor', 110.00),
  ('06 40 31', 'Custom Kitchen Cabinets', 'LF', 'cabinets', 'kitchen', 1.0, 'best', 'material', 550.00);

-- Bathroom Vanities
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('06 40 40', 'Basic Vanity Installation', 'EA', 'vanity', 'bathroom', 3.5, 'good', 'labor', 125.00),
  ('06 40 41', 'Basic Bathroom Vanity 36"', 'EA', 'vanity', 'bathroom', 1.0, 'good', 'material', 380.00),
  
  -- Better Tier
  ('06 40 50', 'Quality Vanity Installation', 'EA', 'vanity', 'bathroom', 4.0, 'better', 'labor', 145.00),
  ('06 40 51', 'Quality Bathroom Vanity 36"', 'EA', 'vanity', 'bathroom', 1.0, 'better', 'material', 650.00),
  
  -- Best Tier
  ('06 40 60', 'Custom Vanity Installation', 'EA', 'vanity', 'bathroom', 5.0, 'best', 'labor', 175.00),
  ('06 40 61', 'Custom Bathroom Vanity 36"', 'EA', 'vanity', 'bathroom', 1.0, 'best', 'material', 1200.00);

-- -----------------------------------------------------------------------------
-- COUNTERTOPS (CSI Division 12-36)
-- Production rates: Fabrication and installation hours per linear foot
-- -----------------------------------------------------------------------------

-- Kitchen Countertops
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier: Laminate
  ('12 36 10', 'Laminate Countertop Installation', 'LF', 'countertops', 'kitchen', 1.2, 'good', 'labor', 35.00),
  ('12 36 11', 'Laminate Countertop Material', 'LF', 'countertops', 'kitchen', 1.0, 'good', 'material', 28.00),
  
  -- Better Tier: Quartz
  ('12 36 20', 'Quartz Countertop Installation', 'LF', 'countertops', 'kitchen', 2.0, 'better', 'labor', 55.00),
  ('12 36 21', 'Quartz Countertop Material', 'LF', 'countertops', 'kitchen', 1.0, 'better', 'material', 85.00),
  
  -- Best Tier: Natural granite
  ('12 36 30', 'Granite Countertop Installation', 'LF', 'countertops', 'kitchen', 2.5, 'best', 'labor', 65.00),
  ('12 36 31', 'Granite Countertop Material', 'LF', 'countertops', 'kitchen', 1.0, 'best', 'material', 95.00);

-- Bathroom Countertops
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('12 36 40', 'Cultured Marble Vanity Top Install', 'EA', 'countertops', 'bathroom', 2.0, 'good', 'labor', 85.00),
  ('12 36 41', 'Cultured Marble Vanity Top 36"', 'EA', 'countertops', 'bathroom', 1.0, 'good', 'material', 165.00),
  
  -- Better Tier
  ('12 36 50', 'Quartz Vanity Top Installation', 'EA', 'countertops', 'bathroom', 2.5, 'better', 'labor', 95.00),
  ('12 36 51', 'Quartz Vanity Top 36"', 'EA', 'countertops', 'bathroom', 1.0, 'better', 'material', 285.00),
  
  -- Best Tier
  ('12 36 60', 'Natural Stone Vanity Top Install', 'EA', 'countertops', 'bathroom', 3.0, 'best', 'labor', 115.00),
  ('12 36 61', 'Natural Stone Vanity Top 36"', 'EA', 'countertops', 'bathroom', 1.0, 'best', 'material', 425.00);

-- -----------------------------------------------------------------------------
-- WALL TREATMENTS (CSI Division 09-30 & 09-91)
-- Tile, paint, and backsplash materials
-- -----------------------------------------------------------------------------

-- Kitchen Backsplash
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('09 30 50', 'Ceramic Subway Tile Installation', 'SF', 'backsplash', 'kitchen', 0.065, 'good', 'labor', 5.50),
  ('09 30 51', 'Ceramic Subway Tile Material', 'SF', 'backsplash', 'kitchen', 1.10, 'good', 'material', 8.75),
  
  -- Better Tier
  ('09 30 55', 'Designer Ceramic Tile Installation', 'SF', 'backsplash', 'kitchen', 0.075, 'better', 'labor', 6.25),
  ('09 30 56', 'Designer Ceramic Tile Material', 'SF', 'backsplash', 'kitchen', 1.12, 'better', 'material', 15.50),
  
  -- Best Tier
  ('09 30 60', 'Natural Stone Backsplash Install', 'SF', 'backsplash', 'kitchen', 0.095, 'best', 'labor', 8.00),
  ('09 30 61', 'Natural Stone Backsplash Material', 'SF', 'backsplash', 'kitchen', 1.15, 'best', 'material', 28.00);

-- Bathroom Wall Tile
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('09 30 70', 'Basic Wall Tile Installation', 'SF', 'wall_tile', 'bathroom', 0.055, 'good', 'labor', 4.75),
  ('09 30 71', 'Basic Ceramic Wall Tile', 'SF', 'wall_tile', 'bathroom', 1.15, 'good', 'material', 6.25),
  
  -- Better Tier
  ('09 30 75', 'Porcelain Wall Tile Installation', 'SF', 'wall_tile', 'bathroom', 0.065, 'better', 'labor', 5.25),
  ('09 30 76', 'Porcelain Wall Tile Material', 'SF', 'wall_tile', 'bathroom', 1.18, 'better', 'material', 11.50),
  
  -- Best Tier
  ('09 30 80', 'Premium Wall Tile Installation', 'SF', 'wall_tile', 'bathroom', 0.085, 'best', 'labor', 6.50),
  ('09 30 81', 'Premium Natural Stone Wall Tile', 'SF', 'wall_tile', 'bathroom', 1.20, 'best', 'material', 24.00);

-- Paint and Primer
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('09 91 10', 'Basic Paint Application', 'SF', 'paint', 'general', 0.012, 'good', 'labor', 1.85),
  ('09 91 11', 'Basic Interior Paint', 'SF', 'paint', 'general', 1.05, 'good', 'material', 1.25),
  
  -- Better Tier  
  ('09 91 15', 'Quality Paint Application', 'SF', 'paint', 'general', 0.014, 'better', 'labor', 2.15),
  ('09 91 16', 'Quality Interior Paint', 'SF', 'paint', 'general', 1.05, 'better', 'material', 1.85),
  
  -- Best Tier
  ('09 91 20', 'Premium Paint Application', 'SF', 'paint', 'general', 0.016, 'best', 'labor', 2.45),
  ('09 91 21', 'Premium Interior Paint', 'SF', 'paint', 'general', 1.05, 'best', 'material', 2.65);

-- -----------------------------------------------------------------------------
-- PLUMBING FIXTURES (CSI Division 22-40)
-- Bathroom fixtures and rough-in work
-- -----------------------------------------------------------------------------

-- Toilets
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('22 41 10', 'Basic Toilet Installation', 'EA', 'plumbing', 'bathroom', 3.5, 'good', 'labor', 185.00),
  ('22 41 11', 'Basic Two-Piece Toilet', 'EA', 'plumbing', 'bathroom', 1.0, 'good', 'material', 245.00),
  
  -- Better Tier
  ('22 41 15', 'Comfort Height Toilet Installation', 'EA', 'plumbing', 'bathroom', 3.8, 'better', 'labor', 195.00),
  ('22 41 16', 'Comfort Height Toilet', 'EA', 'plumbing', 'bathroom', 1.0, 'better', 'material', 385.00),
  
  -- Best Tier
  ('22 41 20', 'Premium Toilet Installation', 'EA', 'plumbing', 'bathroom', 4.2, 'best', 'labor', 215.00),
  ('22 41 21', 'Premium One-Piece Toilet', 'EA', 'plumbing', 'bathroom', 1.0, 'best', 'material', 650.00);

-- Faucets and Fixtures
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Kitchen Faucets
  ('22 41 30', 'Basic Kitchen Faucet Install', 'EA', 'plumbing', 'kitchen', 2.5, 'good', 'labor', 125.00),
  ('22 41 31', 'Basic Kitchen Faucet', 'EA', 'plumbing', 'kitchen', 1.0, 'good', 'material', 165.00),
  ('22 41 35', 'Quality Kitchen Faucet Install', 'EA', 'plumbing', 'kitchen', 2.8, 'better', 'labor', 135.00),
  ('22 41 36', 'Quality Kitchen Faucet', 'EA', 'plumbing', 'kitchen', 1.0, 'better', 'material', 285.00),
  ('22 41 40', 'Premium Kitchen Faucet Install', 'EA', 'plumbing', 'kitchen', 3.2, 'best', 'labor', 155.00),
  ('22 41 41', 'Premium Kitchen Faucet', 'EA', 'plumbing', 'kitchen', 1.0, 'best', 'material', 485.00),
  
  -- Bathroom Faucets
  ('22 41 50', 'Basic Bathroom Faucet Install', 'EA', 'plumbing', 'bathroom', 2.0, 'good', 'labor', 95.00),
  ('22 41 51', 'Basic Bathroom Faucet', 'EA', 'plumbing', 'bathroom', 1.0, 'good', 'material', 125.00),
  ('22 41 55', 'Quality Bathroom Faucet Install', 'EA', 'plumbing', 'bathroom', 2.2, 'better', 'labor', 105.00),
  ('22 41 56', 'Quality Bathroom Faucet', 'EA', 'plumbing', 'bathroom', 1.0, 'better', 'material', 225.00),
  ('22 41 60', 'Premium Bathroom Faucet Install', 'EA', 'plumbing', 'bathroom', 2.5, 'best', 'labor', 125.00),
  ('22 41 61', 'Premium Bathroom Faucet', 'EA', 'plumbing', 'bathroom', 1.0, 'best', 'material', 385.00);

-- Shower/Tub Systems
INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Good Tier
  ('22 42 10', 'Fiberglass Tub/Shower Install', 'EA', 'bathing', 'bathroom', 8.0, 'good', 'labor', 485.00),
  ('22 42 11', 'Fiberglass Tub/Shower Unit', 'EA', 'bathing', 'bathroom', 1.0, 'good', 'material', 650.00),
  
  -- Better Tier
  ('22 42 15', 'Acrylic Shower System Install', 'EA', 'bathing', 'bathroom', 12.0, 'better', 'labor', 625.00),
  ('22 42 16', 'Acrylic Shower System', 'EA', 'bathing', 'bathroom', 1.0, 'better', 'material', 1150.00),
  
  -- Best Tier
  ('22 42 20', 'Tile Shower System Install', 'EA', 'bathing', 'bathroom', 18.0, 'best', 'labor', 875.00),
  ('22 42 21', 'Custom Tile Shower Materials', 'EA', 'bathing', 'bathroom', 1.0, 'best', 'material', 1850.00);

-- -----------------------------------------------------------------------------
-- ELECTRICAL WORK (CSI Division 26-05)
-- Basic electrical rough-in and finish work
-- -----------------------------------------------------------------------------

INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Kitchen Electrical
  ('26 05 10', 'Kitchen Electrical Rough-in', 'EA', 'electrical', 'kitchen', 12.0, 'good', 'labor', 650.00),
  ('26 05 11', 'Kitchen Electrical Materials', 'EA', 'electrical', 'kitchen', 1.0, 'good', 'material', 485.00),
  
  -- Bathroom Electrical  
  ('26 05 20', 'Bathroom Electrical Rough-in', 'EA', 'electrical', 'bathroom', 8.0, 'good', 'labor', 445.00),
  ('26 05 21', 'Bathroom Electrical Materials', 'EA', 'electrical', 'bathroom', 1.0, 'good', 'material', 325.00),
  
  -- Ventilation
  ('23 34 10', 'Exhaust Fan Installation', 'EA', 'ventilation', 'bathroom', 3.5, 'good', 'labor', 165.00),
  ('23 34 11', 'Bathroom Exhaust Fan', 'EA', 'ventilation', 'bathroom', 1.0, 'good', 'material', 125.00),
  ('23 34 15', 'Premium Exhaust Fan Install', 'EA', 'ventilation', 'bathroom', 4.0, 'better', 'labor', 185.00),
  ('23 34 16', 'Premium Bathroom Exhaust Fan', 'EA', 'ventilation', 'bathroom', 1.0, 'better', 'material', 245.00);

-- -----------------------------------------------------------------------------
-- ADDITIONAL MATERIALS
-- Trim, hardware, and finishing materials
-- -----------------------------------------------------------------------------

INSERT INTO Items (csi_code, description, unit, category, subcategory, quantity_per_unit, quality_tier, item_type, national_average_cost) VALUES
  -- Cabinet Hardware
  ('08 71 10', 'Basic Cabinet Hardware Install', 'EA', 'hardware', 'kitchen', 0.25, 'good', 'labor', 8.50),
  ('08 71 11', 'Basic Cabinet Knobs/Pulls', 'EA', 'hardware', 'kitchen', 1.0, 'good', 'material', 4.50),
  ('08 71 15', 'Quality Cabinet Hardware Install', 'EA', 'hardware', 'kitchen', 0.25, 'better', 'labor', 8.50),
  ('08 71 16', 'Quality Cabinet Knobs/Pulls', 'EA', 'hardware', 'kitchen', 1.0, 'better', 'material', 12.50),
  ('08 71 20', 'Premium Cabinet Hardware Install', 'EA', 'hardware', 'kitchen', 0.25, 'best', 'labor', 8.50),
  ('08 71 21', 'Premium Cabinet Knobs/Pulls', 'EA', 'hardware', 'kitchen', 1.0, 'best', 'material', 28.50),
  
  -- Trim and Molding
  ('06 20 10', 'Base Trim Installation', 'LF', 'trim', 'general', 0.15, 'good', 'labor', 3.25),
  ('06 20 11', 'Base Trim Material', 'LF', 'trim', 'general', 1.05, 'good', 'material', 2.85),
  ('06 20 15', 'Crown Molding Installation', 'LF', 'trim', 'general', 0.25, 'better', 'labor', 4.50),
  ('06 20 16', 'Crown Molding Material', 'LF', 'trim', 'general', 1.05, 'better', 'material', 5.25),
  
  -- Underlayment and Prep
  ('03 30 10', 'Floor Preparation/Leveling', 'SF', 'prep', 'general', 0.025, 'good', 'labor', 2.25),
  ('03 30 11', 'Self-Leveling Compound', 'SF', 'prep', 'general', 1.10, 'good', 'material', 1.85),
  
  -- Disposal and Cleanup
  ('01 74 10', 'Demolition and Disposal', 'SF', 'demo', 'general', 0.035, 'good', 'labor', 2.85),
  ('01 74 11', 'Dumpster/Disposal Fees', 'SF', 'demo', 'general', 1.0, 'good', 'material', 0.65);

-- =============================================================================
-- DATA VALIDATION AND SUMMARY
-- =============================================================================

-- Validate item counts by category and quality tier
DO $$
DECLARE
    item_count INTEGER;
    category_count INTEGER;
    tier_distribution RECORD;
BEGIN
    -- Count total items
    SELECT COUNT(*) INTO item_count FROM Items;
    
    -- Count categories
    SELECT COUNT(DISTINCT category) INTO category_count FROM Items;
    
    RAISE NOTICE 'ContractorLens Items Catalog Summary:';
    RAISE NOTICE '- Total Items: %', item_count;
    RAISE NOTICE '- Categories: %', category_count;
    
    -- Show quality tier distribution
    FOR tier_distribution IN 
        SELECT quality_tier, COUNT(*) as count
        FROM Items 
        WHERE quality_tier IS NOT NULL
        GROUP BY quality_tier
        ORDER BY quality_tier
    LOOP
        RAISE NOTICE '- % Tier: % items', tier_distribution.quality_tier, tier_distribution.count;
    END LOOP;
    
    -- Validate production rates
    SELECT COUNT(*) INTO item_count 
    FROM Items 
    WHERE quantity_per_unit IS NULL OR quantity_per_unit <= 0;
    
    IF item_count > 0 THEN
        RAISE WARNING 'Found % items with invalid production rates', item_count;
    ELSE
        RAISE NOTICE '- All production rates valid ✅';
    END IF;
    
    RAISE NOTICE 'Items catalog ready for assembly template creation! 🏗️';
END;
$$;