-- ContractorLens Assembly Recipes
-- Database Engineer: DB002 - Junction table linking assemblies to specific items with quantities  
-- Version: 1.0
-- Created: 2025-09-03

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY RECIPES: The Critical Junction Table
-- Defines exactly what materials and labor go into each assembly package
-- Quantities are per square foot of the assembly's base unit
-- =============================================================================

-- Clear existing assembly items for clean seed (development only)
-- DELETE FROM AssemblyItems; -- Uncomment for development reseeding

-- =============================================================================
-- KITCHEN ECONOMY PACKAGE (Good Tier)
-- Typical 120 SF kitchen with basic, functional finishes
-- =============================================================================

-- Kitchen Economy: Flooring (LVP - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    CASE 
        WHEN i.item_type = 'material' THEN 1.0  -- 1 SF material per 1 SF floor
        WHEN i.item_type = 'labor' THEN 1.0     -- 1 SF labor per 1 SF floor
    END,
    'LVP flooring for kitchen economy package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'flooring' 
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'good';

-- Kitchen Economy: Cabinets (Stock - Good Tier) 
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    CASE 
        WHEN i.item_type = 'material' THEN 0.30  -- 30% of perimeter (36 LF for 120 SF kitchen)
        WHEN i.item_type = 'labor' THEN 0.30     -- Same ratio for labor
    END,
    'Stock cabinets - 30% of kitchen perimeter'
FROM Assemblies a
CROSS JOIN Items i  
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'cabinets'
  AND i.subcategory = 'kitchen' 
  AND i.quality_tier = 'good';

-- Kitchen Economy: Countertops (Laminate - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    CASE 
        WHEN i.item_type = 'material' THEN 0.20  -- ~24 LF for typical kitchen
        WHEN i.item_type = 'labor' THEN 0.20
    END,
    'Laminate countertops - 20% of floor area in LF'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'good';

-- Kitchen Economy: Backsplash (Ceramic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes) 
SELECT
    a.assembly_id,
    i.item_id,
    CASE
        WHEN i.item_type = 'material' THEN 0.25  -- ~30 SF backsplash for 120 SF kitchen
        WHEN i.item_type = 'labor' THEN 0.25
    END,
    'Ceramic subway tile backsplash - 25% of floor area'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'backsplash'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'good';

-- Kitchen Economy: Paint (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id, 
    i.item_id,
    CASE
        WHEN i.item_type = 'material' THEN 2.5  -- ~300 SF wall area for 120 SF kitchen
        WHEN i.item_type = 'labor' THEN 2.5
    END,
    'Interior paint for walls and ceiling - 2.5x floor area'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'paint'
  AND i.subcategory = 'general'
  AND i.quality_tier = 'good';

-- Kitchen Economy: Electrical and Plumbing
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id, 
    CASE
        WHEN i.item_type = 'material' THEN 1.0/120  -- 1 kitchen electrical package per 120 SF
        WHEN i.item_type = 'labor' THEN 1.0/120
    END,
    'Basic kitchen electrical package - 1 per kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'electrical'
  AND i.subcategory = 'kitchen';

INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    CASE
        WHEN i.item_type = 'material' THEN 1.0/120  -- 1 kitchen faucet per kitchen
        WHEN i.item_type = 'labor' THEN 1.0/120
    END,
    'Basic kitchen faucet - 1 per kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Economy Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'kitchen' 
  AND i.quality_tier = 'good';

-- =============================================================================
-- KITCHEN STANDARD PACKAGE (Better Tier)
-- Mid-range kitchen with quality finishes
-- =============================================================================

-- Kitchen Standard: Flooring (Ceramic - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    CASE 
        WHEN i.item_type = 'material' THEN 1.0
        WHEN i.item_type = 'labor' THEN 1.0
    END,
    'Ceramic tile flooring for standard kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'flooring'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'better';

-- Kitchen Standard: Cabinets (Semi-Custom - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    0.30,  -- Same cabinet ratio as economy
    'Semi-custom cabinets for standard kitchen'
FROM Assemblies a
CROSS JOIN Items i  
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'cabinets'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'better';

-- Kitchen Standard: Countertops (Quartz - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    0.20,
    'Quartz countertops for standard kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'better';

-- Kitchen Standard: Backsplash (Designer - Better Tier)  
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    0.25,
    'Designer ceramic backsplash for standard kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'backsplash'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'better';

-- Kitchen Standard: Paint (Quality - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    2.5,
    'Quality paint for standard kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'paint'
  AND i.subcategory = 'general'
  AND i.quality_tier = 'better';

-- Kitchen Standard: Plumbing (Quality Faucet)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/120,
    'Quality kitchen faucet for standard package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Standard Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'better';

-- =============================================================================
-- KITCHEN PREMIUM PACKAGE (Best Tier) 
-- High-end kitchen with luxury materials
-- =============================================================================

-- Kitchen Premium: Flooring (Hardwood - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    1.0,
    'Engineered hardwood flooring for premium kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'flooring'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'best';

-- Kitchen Premium: Cabinets (Custom - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    0.35,  -- Slightly more cabinets for premium design
    'Custom cabinets for premium kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'cabinets'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'best';

-- Kitchen Premium: Countertops (Granite - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    0.22,  -- Slightly more counter space
    'Granite countertops for premium kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'best';

-- Kitchen Premium: Backsplash (Natural Stone - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    0.28,  -- More elaborate backsplash
    'Natural stone backsplash for premium kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'backsplash'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'best';

-- Kitchen Premium: Paint (Premium - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    2.5,
    'Premium paint for premium kitchen'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'paint'
  AND i.subcategory = 'general'
  AND i.quality_tier = 'best';

-- Kitchen Premium: Plumbing (Premium Faucet)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/120,
    'Premium kitchen faucet for premium package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Kitchen Premium Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'kitchen'
  AND i.quality_tier = 'best';

-- =============================================================================
-- BATHROOM ECONOMY PACKAGE (Good Tier)
-- Essential bathroom renovation - 50 SF typical
-- =============================================================================

-- Bathroom Economy: Flooring (Basic Ceramic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    1.0,
    'Basic ceramic tile flooring for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'flooring'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Wall Tile (Basic - Good Tier) 
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.2,  -- 60 SF wall tile for 50 SF bathroom
    'Basic wall tile for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'wall_tile'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Vanity (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 vanity per 50 SF bathroom
    'Basic 36" vanity for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'vanity'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Vanity Countertop (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 vanity top per bathroom
    'Cultured marble vanity top for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Toilet (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 toilet per bathroom
    'Basic two-piece toilet for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Toilet%'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Faucet (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 faucet per bathroom
    'Basic bathroom faucet for economy package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Bathroom Faucet%'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Tub/Shower (Fiberglass - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 tub/shower per bathroom
    'Fiberglass tub/shower for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'bathing'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Electrical and Ventilation
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 electrical package per bathroom
    'Basic bathroom electrical for economy package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'electrical'
  AND i.subcategory = 'bathroom';

INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,  -- 1 exhaust fan per bathroom
    'Basic exhaust fan for economy bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'ventilation'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'good';

-- Bathroom Economy: Paint (Basic - Good Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    0.8,  -- 40 SF painted area for 50 SF bathroom (rest is tiled)
    'Basic paint for non-tiled areas'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Economy Package'
  AND i.category = 'paint'
  AND i.subcategory = 'general'
  AND i.quality_tier = 'good';

-- =============================================================================
-- BATHROOM STANDARD PACKAGE (Better Tier)
-- Quality bathroom with modern fixtures
-- =============================================================================

-- Bathroom Standard: Flooring (Porcelain - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    1.0,
    'Porcelain tile flooring for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'flooring'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Wall Tile (Porcelain - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.2,
    'Porcelain wall tile for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'wall_tile'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Vanity (Quality - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Quality vanity for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'vanity'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Vanity Countertop (Quartz - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Quartz vanity top for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Toilet (Comfort Height - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Comfort height toilet for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Toilet%'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Faucet (Quality - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Quality bathroom faucet for standard package'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Bathroom Faucet%'
  AND i.quality_tier = 'better';

-- Bathroom Standard: Shower System (Acrylic - Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Acrylic shower system for standard bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Standard Package'
  AND i.category = 'bathing'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';

-- =============================================================================
-- BATHROOM PREMIUM PACKAGE (Best Tier)
-- Luxury bathroom with premium materials  
-- =============================================================================

-- Bathroom Premium: Flooring (Natural Stone - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT 
    a.assembly_id,
    i.item_id,
    1.0,
    'Natural stone flooring for premium bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'flooring'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Wall Tile (Natural Stone - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.3,  -- More elaborate tiling in premium
    'Premium natural stone wall tile'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'wall_tile'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Vanity (Custom - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Custom vanity for premium bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'vanity'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Vanity Countertop (Natural Stone - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Natural stone vanity top for premium bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'countertops'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Toilet (Premium - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Premium one-piece toilet'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Toilet%'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Faucet (Premium - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Premium bathroom faucet'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'plumbing'
  AND i.subcategory = 'bathroom'
  AND i.description LIKE '%Bathroom Faucet%'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Tile Shower (Custom - Best Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Custom tile shower system for premium bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'bathing'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'best';

-- Bathroom Premium: Enhanced Ventilation (Better Tier)
INSERT INTO AssemblyItems (assembly_id, item_id, quantity, notes)
SELECT
    a.assembly_id,
    i.item_id,
    1.0/50,
    'Premium exhaust fan for premium bathroom'
FROM Assemblies a
CROSS JOIN Items i
WHERE a.name = 'Bathroom Premium Package'
  AND i.category = 'ventilation'
  AND i.subcategory = 'bathroom'
  AND i.quality_tier = 'better';  -- Use better tier fan for best bathroom

-- =============================================================================
-- VALIDATION AND SUMMARY
-- =============================================================================

DO $$
DECLARE
    total_relationships INTEGER;
    kitchen_items INTEGER;
    bathroom_items INTEGER;
    recipe_summary RECORD;
BEGIN
    -- Count total assembly-item relationships
    SELECT COUNT(*) INTO total_relationships FROM AssemblyItems;
    
    -- Count kitchen assembly items
    SELECT COUNT(DISTINCT ai.item_id) INTO kitchen_items
    FROM AssemblyItems ai
    JOIN Assemblies a ON ai.assembly_id = a.assembly_id
    WHERE a.category = 'kitchen';
    
    -- Count bathroom assembly items  
    SELECT COUNT(DISTINCT ai.item_id) INTO bathroom_items
    FROM AssemblyItems ai
    JOIN Assemblies a ON ai.assembly_id = a.assembly_id
    WHERE a.category = 'bathroom';
    
    RAISE NOTICE 'ContractorLens Assembly Recipes Summary:';
    RAISE NOTICE '- Total Assembly-Item Relationships: %', total_relationships;
    RAISE NOTICE '- Unique Kitchen Items Used: %', kitchen_items;
    RAISE NOTICE '- Unique Bathroom Items Used: %', bathroom_items;
    
    -- Show recipe counts per assembly
    FOR recipe_summary IN
        SELECT 
            a.name,
            COUNT(*) as item_count,
            ROUND(AVG(ai.quantity), 3) as avg_quantity
        FROM Assemblies a
        JOIN AssemblyItems ai ON a.assembly_id = ai.assembly_id
        GROUP BY a.assembly_id, a.name
        ORDER BY a.category, a.name
    LOOP
        RAISE NOTICE '- %: % items, avg qty %', recipe_summary.name, recipe_summary.item_count, recipe_summary.avg_quantity;
    END LOOP;
    
    RAISE NOTICE '✅ Assembly recipes completed! Ready for validation queries! 🏗️';
END;
$$;