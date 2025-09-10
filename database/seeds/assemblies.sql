-- ContractorLens Assembly Templates
-- Database Engineer: DB002 - Kitchen and Bathroom renovation packages
-- Version: 1.0
-- Created: 2025-09-03

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY TEMPLATES: Kitchen and Bathroom Renovation Packages
-- These are construction "recipes" that combine materials and labor
-- =============================================================================

-- Clear existing assemblies for clean seed (development only)
-- DELETE FROM Assemblies; -- Uncomment for development reseeding

-- -----------------------------------------------------------------------------
-- KITCHEN ASSEMBLIES
-- Based on typical 120 SF kitchen (12' x 10') with 44 LF perimeter
-- Each quality tier represents different finish levels
-- -----------------------------------------------------------------------------

INSERT INTO Assemblies (assembly_id, name, description, category, csi_code, base_unit) VALUES
  -- Economy Kitchen Package (Good Tier)
  (gen_random_uuid(), 
   'Kitchen Economy Package', 
   'Essential kitchen renovation with functional materials and basic finishes. Includes LVP flooring, stock cabinets, laminate countertops, ceramic backsplash, and standard electrical. Perfect for rental properties or budget-conscious homeowners.',
   'kitchen',
   '00 00 01',
   'SF'),
   
  -- Standard Kitchen Package (Better Tier)  
  (gen_random_uuid(),
   'Kitchen Standard Package',
   'Mid-range kitchen renovation with quality materials and attractive finishes. Features ceramic tile flooring, semi-custom cabinets, quartz countertops, designer backsplash, and enhanced electrical. Ideal for family homes seeking durability and style.',
   'kitchen', 
   '00 00 02',
   'SF'),
   
  -- Premium Kitchen Package (Best Tier)
  (gen_random_uuid(),
   'Kitchen Premium Package', 
   'High-end kitchen renovation with luxury materials and premium finishes. Includes engineered hardwood flooring, custom cabinets, granite countertops, natural stone backsplash, and premium fixtures. For homeowners who want the finest quality.',
   'kitchen',
   '00 00 03', 
   'SF');

-- -----------------------------------------------------------------------------
-- BATHROOM ASSEMBLIES  
-- Based on typical 50 SF bathroom (8' x 6.25') 
-- Full renovation including flooring, fixtures, tile, and electrical
-- -----------------------------------------------------------------------------

INSERT INTO Assemblies (assembly_id, name, description, category, csi_code, base_unit) VALUES
  -- Economy Bathroom Package (Good Tier)
  (gen_random_uuid(),
   'Bathroom Economy Package',
   'Essential bathroom renovation with reliable, functional materials. Includes ceramic tile flooring, basic fixtures (toilet, vanity, faucet), fiberglass tub/shower, ceramic wall tile, and standard electrical/ventilation. Cost-effective solution for rentals or starter homes.',
   'bathroom',
   '00 00 04',
   'SF'),
   
  -- Standard Bathroom Package (Better Tier)
  (gen_random_uuid(),
   'Bathroom Standard Package', 
   'Quality bathroom renovation with modern fixtures and attractive finishes. Features porcelain tile flooring, comfort-height toilet, quality vanity, acrylic shower system, upgraded wall tile, and enhanced ventilation. Perfect balance of style and value.',
   'bathroom',
   '00 00 05',
   'SF'),
   
  -- Premium Bathroom Package (Best Tier)
  (gen_random_uuid(),
   'Bathroom Premium Package',
   'Luxury bathroom renovation with premium materials and spa-like finishes. Includes natural stone flooring, premium one-piece toilet, custom vanity, tile shower system, natural stone wall tile, and high-end fixtures. Creates a personal retreat.',
   'bathroom',
   '00 00 06',
   'SF');

-- =============================================================================
-- ASSEMBLY METADATA AND VALIDATION
-- =============================================================================

-- Update timestamps for all assemblies
UPDATE Assemblies 
SET created_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
WHERE category IN ('kitchen', 'bathroom');

-- Validate assembly creation
DO $$
DECLARE
    kitchen_count INTEGER;
    bathroom_count INTEGER;
    total_assemblies INTEGER;
BEGIN
    -- Count kitchen assemblies
    SELECT COUNT(*) INTO kitchen_count 
    FROM Assemblies 
    WHERE category = 'kitchen';
    
    -- Count bathroom assemblies
    SELECT COUNT(*) INTO bathroom_count 
    FROM Assemblies 
    WHERE category = 'bathroom';
    
    -- Total count
    SELECT COUNT(*) INTO total_assemblies 
    FROM Assemblies;
    
    RAISE NOTICE 'ContractorLens Assembly Templates Created:';
    RAISE NOTICE '- Kitchen Packages: % (Economy/Standard/Premium)', kitchen_count;
    RAISE NOTICE '- Bathroom Packages: % (Economy/Standard/Premium)', bathroom_count;  
    RAISE NOTICE '- Total Assemblies: %', total_assemblies;
    
    -- Validate required assemblies
    IF kitchen_count = 3 AND bathroom_count = 3 THEN
        RAISE NOTICE '✅ All required assembly templates created successfully!';
    ELSE
        RAISE WARNING '⚠️  Expected 3 kitchen + 3 bathroom assemblies, found % + %', kitchen_count, bathroom_count;
    END IF;
    
    RAISE NOTICE 'Ready for AssemblyItems recipe creation! 🏗️';
END;
$$;

-- Create helpful views for assembly browsing
CREATE OR REPLACE VIEW assembly_catalog AS
SELECT 
    assembly_id,
    name,
    description,
    category,
    CASE 
        WHEN name LIKE '%Economy%' THEN 'good'
        WHEN name LIKE '%Standard%' THEN 'better' 
        WHEN name LIKE '%Premium%' THEN 'best'
        ELSE 'unknown'
    END as quality_tier,
    base_unit,
    created_at
FROM Assemblies
ORDER BY category, quality_tier;