-- ContractorLens Location Cost Modifiers
-- Database Engineer: DB003 - Geographic pricing with Construction Cost Index multipliers
-- Version: 1.0
-- Created: 2025-09-04
-- Data Source: Q4 2024 Construction Cost Index

SET search_path TO contractorlens, public;

-- =============================================================================
-- LOCATION COST MODIFIERS: Geographic Pricing Foundation
-- Based on Construction Cost Index (CCI) data for accurate regional pricing
-- Enables Assembly Engine cost hierarchy: RetailPrices → national_average × location_modifier
-- =============================================================================

-- Clear existing location modifiers for clean seed (development only)
-- DELETE FROM LocationCostModifiers; -- Uncomment for development reseeding

-- -----------------------------------------------------------------------------
-- TIER 1: HIGH COST MARKETS (120%+ above national average)
-- Premium metros with significantly elevated construction costs
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- SAN FRANCISCO BAY AREA
('San Francisco, CA', 'CA', '94000-94199', 1.35, 1.40, '2024-10-01', NOW(), NOW()),
('San Jose, CA', 'CA', '95000-95199', 1.32, 1.38, '2024-10-01', NOW(), NOW()),
('Oakland, CA', 'CA', '94600-94699', 1.30, 1.35, '2024-10-01', NOW(), NOW()),
('Palo Alto, CA', 'CA', '94300-94306', 1.42, 1.50, '2024-10-01', NOW(), NOW()),
('Mountain View, CA', 'CA', '94040-94043', 1.38, 1.45, '2024-10-01', NOW(), NOW()),

-- NEW YORK METRO AREA
('New York, NY', 'NY', '10000-10299', 1.30, 1.45, '2024-10-01', NOW(), NOW()),
('Manhattan, NY', 'NY', '10000-10099', 1.40, 1.55, '2024-10-01', NOW(), NOW()),
('Brooklyn, NY', 'NY', '11200-11299', 1.28, 1.42, '2024-10-01', NOW(), NOW()),
('Queens, NY', 'NY', '11300-11499', 1.25, 1.38, '2024-10-01', NOW(), NOW()),
('Bronx, NY', 'NY', '10400-10499', 1.22, 1.35, '2024-10-01', NOW(), NOW()),
('Staten Island, NY', 'NY', '10300-10314', 1.20, 1.32, '2024-10-01', NOW(), NOW()),

-- LOS ANGELES METRO AREA
('Los Angeles, CA', 'CA', '90000-90899', 1.25, 1.35, '2024-10-01', NOW(), NOW()),
('Santa Monica, CA', 'CA', '90400-90499', 1.32, 1.42, '2024-10-01', NOW(), NOW()),
('Beverly Hills, CA', 'CA', '90200-90299', 1.45, 1.50, '2024-10-01', NOW(), NOW()),
('West Hollywood, CA', 'CA', '90069-90069', 1.38, 1.45, '2024-10-01', NOW(), NOW()),
('Venice, CA', 'CA', '90291-90294', 1.28, 1.38, '2024-10-01', NOW(), NOW()),
('Pasadena, CA', 'CA', '91100-91199', 1.22, 1.30, '2024-10-01', NOW(), NOW()),

-- SEATTLE METRO AREA
('Seattle, WA', 'WA', '98000-98199', 1.20, 1.30, '2024-10-01', NOW(), NOW()),
('Bellevue, WA', 'WA', '98004-98008', 1.25, 1.35, '2024-10-01', NOW(), NOW()),
('Redmond, WA', 'WA', '98050-98073', 1.22, 1.32, '2024-10-01', NOW(), NOW()),
('Kirkland, WA', 'WA', '98033-98034', 1.20, 1.28, '2024-10-01', NOW(), NOW());

-- -----------------------------------------------------------------------------  
-- TIER 2: ABOVE AVERAGE MARKETS (105%-119% above national average)
-- Major metros with moderately elevated construction costs
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- BOSTON METRO AREA
('Boston, MA', 'MA', '02000-02299', 1.15, 1.25, '2024-10-01', NOW(), NOW()),
('Cambridge, MA', 'MA', '02138-02142', 1.20, 1.30, '2024-10-01', NOW(), NOW()),
('Somerville, MA', 'MA', '02143-02145', 1.18, 1.28, '2024-10-01', NOW(), NOW()),
('Newton, MA', 'MA', '02458-02468', 1.22, 1.32, '2024-10-01', NOW(), NOW()),

-- CHICAGO METRO AREA
('Chicago, IL', 'IL', '60000-60699', 1.10, 1.15, '2024-10-01', NOW(), NOW()),
('Naperville, IL', 'IL', '60540-60565', 1.12, 1.18, '2024-10-01', NOW(), NOW()),
('Evanston, IL', 'IL', '60201-60204', 1.14, 1.20, '2024-10-01', NOW(), NOW()),
('Oak Park, IL', 'IL', '60301-60304', 1.13, 1.19, '2024-10-01', NOW(), NOW()),

-- WASHINGTON DC METRO AREA
('Washington, DC', 'DC', '20000-20099', 1.18, 1.28, '2024-10-01', NOW(), NOW()),
('Alexandria, VA', 'VA', '22300-22315', 1.16, 1.26, '2024-10-01', NOW(), NOW()),
('Arlington, VA', 'VA', '22200-22217', 1.20, 1.30, '2024-10-01', NOW(), NOW()),
('Bethesda, MD', 'MD', '20810-20817', 1.22, 1.32, '2024-10-01', NOW(), NOW()),

-- MIAMI METRO AREA
('Miami, FL', 'FL', '33000-33199', 1.08, 1.10, '2024-10-01', NOW(), NOW()),
('Miami Beach, FL', 'FL', '33139-33154', 1.15, 1.18, '2024-10-01', NOW(), NOW()),
('Coral Gables, FL', 'FL', '33134-33146', 1.12, 1.15, '2024-10-01', NOW(), NOW()),
('Fort Lauderdale, FL', 'FL', '33300-33399', 1.06, 1.08, '2024-10-01', NOW(), NOW()),

-- DENVER METRO AREA
('Denver, CO', 'CO', '80000-80299', 1.05, 1.08, '2024-10-01', NOW(), NOW()),
('Boulder, CO', 'CO', '80301-80310', 1.12, 1.15, '2024-10-01', NOW(), NOW()),
('Golden, CO', 'CO', '80401-80403', 1.07, 1.10, '2024-10-01', NOW(), NOW()),

-- PORTLAND METRO AREA
('Portland, OR', 'OR', '97000-97299', 1.12, 1.18, '2024-10-01', NOW(), NOW()),
('Beaverton, OR', 'OR', '97005-97008', 1.10, 1.15, '2024-10-01', NOW(), NOW()),
('Lake Oswego, OR', 'OR', '97034-97035', 1.15, 1.22, '2024-10-01', NOW(), NOW());

-- -----------------------------------------------------------------------------
-- TIER 3: AVERAGE MARKETS (95%-104% of national average)  
-- Markets close to national baseline with minor variations
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- PHILADELPHIA METRO AREA
('Philadelphia, PA', 'PA', '19000-19199', 1.02, 1.05, '2024-10-01', NOW(), NOW()),
('King of Prussia, PA', 'PA', '19406-19406', 1.08, 1.12, '2024-10-01', NOW(), NOW()),

-- PHOENIX METRO AREA
('Phoenix, AZ', 'AZ', '85000-85299', 0.98, 0.95, '2024-10-01', NOW(), NOW()),
('Scottsdale, AZ', 'AZ', '85250-85259', 1.05, 1.02, '2024-10-01', NOW(), NOW()),
('Tempe, AZ', 'AZ', '85280-85284', 1.00, 0.97, '2024-10-01', NOW(), NOW()),

-- AUSTIN METRO AREA
('Austin, TX', 'TX', '78700-78799', 1.02, 0.98, '2024-10-01', NOW(), NOW()),
('Round Rock, TX', 'TX', '78664-78665', 1.00, 0.96, '2024-10-01', NOW(), NOW()),

-- RALEIGH-DURHAM METRO AREA
('Raleigh, NC', 'NC', '27600-27699', 0.98, 0.95, '2024-10-01', NOW(), NOW()),
('Durham, NC', 'NC', '27700-27717', 0.96, 0.93, '2024-10-01', NOW(), NOW()),
('Chapel Hill, NC', 'NC', '27514-27517', 1.02, 1.00, '2024-10-01', NOW(), NOW()),

-- NASHVILLE METRO AREA
('Nashville, TN', 'TN', '37000-37299', 0.95, 0.90, '2024-10-01', NOW(), NOW()),
('Franklin, TN', 'TN', '37064-37068', 1.00, 0.95, '2024-10-01', NOW(), NOW());

-- -----------------------------------------------------------------------------
-- TIER 4: BELOW AVERAGE MARKETS (80%-94% of national average)
-- Lower cost markets with competitive construction pricing
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- DALLAS-FORT WORTH METRO AREA
('Dallas, TX', 'TX', '75000-75399', 0.95, 0.90, '2024-10-01', NOW(), NOW()),
('Plano, TX', 'TX', '75023-75094', 0.98, 0.93, '2024-10-01', NOW(), NOW()),
('Fort Worth, TX', 'TX', '76000-76199', 0.92, 0.88, '2024-10-01', NOW(), NOW()),
('Irving, TX', 'TX', '75060-75063', 0.94, 0.89, '2024-10-01', NOW(), NOW()),

-- ATLANTA METRO AREA  
('Atlanta, GA', 'GA', '30000-30399', 0.92, 0.88, '2024-10-01', NOW(), NOW()),
('Sandy Springs, GA', 'GA', '30328-30350', 0.95, 0.92, '2024-10-01', NOW(), NOW()),
('Alpharetta, GA', 'GA', '30004-30009', 0.94, 0.91, '2024-10-01', NOW(), NOW()),
('Marietta, GA', 'GA', '30060-30068', 0.90, 0.87, '2024-10-01', NOW(), NOW()),

-- KANSAS CITY METRO AREA
('Kansas City, MO', 'MO', '64000-64199', 0.85, 0.82, '2024-10-01', NOW(), NOW()),
('Kansas City, KS', 'KS', '66000-66199', 0.83, 0.80, '2024-10-01', NOW(), NOW()),
('Overland Park, KS', 'KS', '66200-66299', 0.88, 0.85, '2024-10-01', NOW(), NOW()),

-- COLUMBUS METRO AREA
('Columbus, OH', 'OH', '43000-43299', 0.88, 0.85, '2024-10-01', NOW(), NOW()),
('Dublin, OH', 'OH', '43016-43017', 0.92, 0.89, '2024-10-01', NOW(), NOW()),

-- CINCINNATI METRO AREA
('Cincinnati, OH', 'OH', '45000-45299', 0.86, 0.83, '2024-10-01', NOW(), NOW()),

-- LOUISVILLE METRO AREA
('Louisville, KY', 'KY', '40200-40299', 0.84, 0.81, '2024-10-01', NOW(), NOW()),

-- OKLAHOMA CITY METRO AREA
('Oklahoma City, OK', 'OK', '73000-73199', 0.82, 0.79, '2024-10-01', NOW(), NOW());

-- -----------------------------------------------------------------------------
-- HIGH-END SPECIALTY MARKETS (140%+ above national average)
-- Resort towns and luxury markets with premium construction costs
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- LUXURY RESORT MARKETS
('Aspen, CO', 'CO', '81611-81615', 1.60, 1.75, '2024-10-01', NOW(), NOW()),
('Jackson, WY', 'WY', '83001-83025', 1.45, 1.55, '2024-10-01', NOW(), NOW()),
('Napa, CA', 'CA', '94558-94581', 1.28, 1.35, '2024-10-01', NOW(), NOW()),
('Big Sur, CA', 'CA', '93920-93920', 1.55, 1.65, '2024-10-01', NOW(), NOW()),

-- HIGH-END EAST COAST MARKETS
('Hamptons, NY', 'NY', '11930-11980', 1.50, 1.65, '2024-10-01', NOW(), NOW()),
('Martha\'s Vineyard, MA', 'MA', '02539-02575', 1.45, 1.60, '2024-10-01', NOW(), NOW()),
('Nantucket, MA', 'MA', '02554-02584', 1.50, 1.65, '2024-10-01', NOW(), NOW()),

-- FLORIDA LUXURY MARKETS
('Key West, FL', 'FL', '33040-33045', 1.35, 1.40, '2024-10-01', NOW(), NOW()),
('Naples, FL', 'FL', '34100-34119', 1.18, 1.25, '2024-10-01', NOW(), NOW());

-- -----------------------------------------------------------------------------
-- NATIONAL BASELINE AND FALLBACK COVERAGE
-- Default multiplier for areas not specifically covered
-- -----------------------------------------------------------------------------

INSERT INTO LocationCostModifiers (metro_name, state_code, zip_code_range, material_modifier, labor_modifier, effective_date, created_at, updated_at) VALUES

-- NATIONAL BASELINE (fallback for uncovered areas)
('National Baseline', 'US', '00000-99999', 1.00, 1.00, '2024-10-01', NOW(), NOW());

-- =============================================================================
-- DATA VALIDATION AND SUMMARY
-- =============================================================================

-- Validate location modifier creation
DO $$
DECLARE
    total_locations INTEGER;
    high_cost_count INTEGER;
    above_avg_count INTEGER;
    below_avg_count INTEGER;
    coverage_stats RECORD;
BEGIN
    -- Count total locations
    SELECT COUNT(*) INTO total_locations FROM LocationCostModifiers;
    
    -- Count by cost tier
    SELECT COUNT(*) INTO high_cost_count 
    FROM LocationCostModifiers 
    WHERE material_modifier >= 1.20;
    
    SELECT COUNT(*) INTO above_avg_count 
    FROM LocationCostModifiers 
    WHERE material_modifier >= 1.05 AND material_modifier < 1.20;
    
    SELECT COUNT(*) INTO below_avg_count 
    FROM LocationCostModifiers 
    WHERE material_modifier < 0.95;
    
    RAISE NOTICE 'ContractorLens Location Cost Modifiers Summary:';
    RAISE NOTICE '- Total Locations: %', total_locations;
    RAISE NOTICE '- High Cost Markets (120%+): %', high_cost_count;
    RAISE NOTICE '- Above Average Markets (105-119%%): %', above_avg_count; 
    RAISE NOTICE '- Below Average Markets (<95%%): %', below_avg_count;
    
    -- Show cost range distribution
    FOR coverage_stats IN 
        SELECT 
            CASE 
                WHEN material_modifier >= 1.40 THEN 'Premium (140%+)'
                WHEN material_modifier >= 1.20 THEN 'High Cost (120-139%)'
                WHEN material_modifier >= 1.05 THEN 'Above Average (105-119%)'
                WHEN material_modifier >= 0.95 THEN 'Average (95-104%)'
                ELSE 'Below Average (<95%)'
            END as cost_tier,
            COUNT(*) as location_count,
            ROUND(AVG(material_modifier)::numeric, 3) as avg_material_mod,
            ROUND(AVG(labor_modifier)::numeric, 3) as avg_labor_mod
        FROM LocationCostModifiers 
        WHERE metro_name != 'National Baseline'
        GROUP BY 
            CASE 
                WHEN material_modifier >= 1.40 THEN 'Premium (140%+)'
                WHEN material_modifier >= 1.20 THEN 'High Cost (120-139%)'
                WHEN material_modifier >= 1.05 THEN 'Above Average (105-119%)'
                WHEN material_modifier >= 0.95 THEN 'Average (95-104%)'
                ELSE 'Below Average (<95%)'
            END
        ORDER BY avg_material_mod DESC
    LOOP
        RAISE NOTICE '- %: % locations, avg material %.3f, avg labor %.3f', 
            coverage_stats.cost_tier, 
            coverage_stats.location_count,
            coverage_stats.avg_material_mod,
            coverage_stats.avg_labor_mod;
    END LOOP;
    
    -- Validate data quality
    SELECT COUNT(*) INTO total_locations 
    FROM LocationCostModifiers 
    WHERE material_modifier IS NULL 
       OR labor_modifier IS NULL 
       OR material_modifier <= 0 
       OR labor_modifier <= 0;
    
    IF total_locations > 0 THEN
        RAISE WARNING 'Found % locations with invalid modifiers', total_locations;
    ELSE
        RAISE NOTICE '✅ All location modifiers valid';
    END IF;
    
    RAISE NOTICE 'Location cost modifiers ready for Assembly Engine integration! 🗺️💰';
END;
$$;

-- Create helpful views for location browsing and Assembly Engine queries
CREATE OR REPLACE VIEW location_cost_tiers AS
SELECT 
    metro_name,
    state_code,
    zip_code_range,
    material_modifier,
    labor_modifier,
    CASE 
        WHEN material_modifier >= 1.40 THEN 'Premium (140%+)'
        WHEN material_modifier >= 1.20 THEN 'High Cost (120-139%)'
        WHEN material_modifier >= 1.05 THEN 'Above Average (105-119%)'
        WHEN material_modifier >= 0.95 THEN 'Average (95-104%)'
        ELSE 'Below Average (<95%)'
    END as cost_tier,
    ROUND((material_modifier - 1.0) * 100, 1) as material_percent_diff,
    ROUND((labor_modifier - 1.0) * 100, 1) as labor_percent_diff,
    effective_date
FROM LocationCostModifiers 
WHERE metro_name != 'National Baseline'
ORDER BY material_modifier DESC;

-- Create Assembly Engine lookup optimization view
CREATE OR REPLACE VIEW assembly_engine_location_lookup AS
SELECT 
    location_id,
    metro_name,
    state_code,
    zip_code_range,
    material_modifier,
    labor_modifier,
    effective_date,
    expiry_date
FROM LocationCostModifiers
WHERE effective_date <= CURRENT_DATE
  AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
ORDER BY 
    CASE WHEN metro_name = 'National Baseline' THEN 1 ELSE 0 END,  -- National baseline last
    material_modifier DESC;  -- High-cost markets first for priority matching

COMMENT ON VIEW location_cost_tiers IS 'Location modifiers organized by cost tiers for analysis and reporting';
COMMENT ON VIEW assembly_engine_location_lookup IS 'Optimized view for Assembly Engine location-based cost calculations';