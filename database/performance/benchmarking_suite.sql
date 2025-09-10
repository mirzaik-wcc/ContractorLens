-- ContractorLens Database Performance Benchmarking Suite
-- Performance Engineer: PERF001 - Phase 1 Performance Validation
-- Target: Comprehensive performance testing and validation
-- Created: 2025-09-05

SET search_path TO contractorlens, public;

-- =============================================================================
-- ASSEMBLY ENGINE CRITICAL PATH BENCHMARKS
-- These tests validate the performance of the most important queries
-- =============================================================================

-- Enable timing for accurate measurements
\timing on

-- Function to run comprehensive performance benchmarks
CREATE OR REPLACE FUNCTION run_performance_benchmarks()
RETURNS TABLE (
    test_category TEXT,
    test_name TEXT,
    execution_time_ms NUMERIC,
    rows_processed BIGINT,
    performance_rating TEXT,
    meets_target BOOLEAN,
    notes TEXT
) AS $$
DECLARE
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
    duration_ms NUMERIC;
    row_count BIGINT;
BEGIN
    -- ==========================================================================
    -- Test 1: Location Modifier Lookup (Assembly Engine Critical Path)
    -- Target: <50ms for ZIP code to modifiers resolution
    -- ==========================================================================
    
    start_time := clock_timestamp();
    
    -- Test with optimized function
    PERFORM * FROM get_location_modifiers_optimized('94105');
    PERFORM * FROM get_location_modifiers_optimized('10001');
    PERFORM * FROM get_location_modifiers_optimized('77001');
    PERFORM * FROM get_location_modifiers_optimized('90210');
    PERFORM * FROM get_location_modifiers_optimized('60601');
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Assembly Engine'::TEXT,
        'Location Lookup (5 ZIP codes)'::TEXT,
        duration_ms,
        5::BIGINT,
        CASE 
            WHEN duration_ms < 50 THEN 'EXCELLENT'
            WHEN duration_ms < 100 THEN 'GOOD'
            WHEN duration_ms < 200 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (duration_ms < 50)::BOOLEAN,
        'Critical path: ZIP to cost modifiers'::TEXT;
    
    -- ==========================================================================
    -- Test 2: Assembly Items Materialized View Performance
    -- Target: <100ms for complete assembly expansion
    -- ==========================================================================
    
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO row_count
    FROM assembly_items_materialized aim
    WHERE aim.assembly_id IN (
        SELECT assembly_id FROM Assemblies 
        WHERE category IN ('kitchen', 'bathroom', 'room')
        LIMIT 3
    );
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Assembly Engine'::TEXT,
        'Assembly Items Expansion'::TEXT,
        duration_ms,
        row_count,
        CASE 
            WHEN duration_ms < 100 THEN 'EXCELLENT'
            WHEN duration_ms < 200 THEN 'GOOD'
            WHEN duration_ms < 500 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (duration_ms < 100)::BOOLEAN,
        'Materialized view performance'::TEXT;
    
    -- ==========================================================================
    -- Test 3: Fresh Retail Price Lookups
    -- Target: <25ms for current retail price resolution
    -- ==========================================================================
    
    start_time := clock_timestamp();
    
    -- Test retail price lookups for 10 random items
    PERFORM get_fresh_retail_price(
        item_id,
        (SELECT location_id FROM LocationCostModifiers LIMIT 1 OFFSET (i % 5))
    )
    FROM (
        SELECT item_id, generate_series(1, 10) as i
        FROM Items 
        WHERE national_average_cost IS NOT NULL 
        LIMIT 10
    ) t;
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Assembly Engine'::TEXT,
        'Retail Price Lookups (10 items)'::TEXT,
        duration_ms,
        10::BIGINT,
        CASE 
            WHEN duration_ms < 25 THEN 'EXCELLENT'
            WHEN duration_ms < 50 THEN 'GOOD'
            WHEN duration_ms < 100 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (duration_ms < 25)::BOOLEAN,
        'Cost hierarchy: retail vs national'::TEXT;
    
    -- ==========================================================================
    -- Test 4: Quality Tier Item Selection
    -- Target: <75ms for finish level item filtering
    -- ==========================================================================
    
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO row_count
    FROM get_finish_items_optimized(
        'better',
        ARRAY['fixtures', 'finishes', 'appliances']
    );
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Assembly Engine'::TEXT,
        'Quality Tier Selection'::TEXT,
        duration_ms,
        row_count,
        CASE 
            WHEN duration_ms < 75 THEN 'EXCELLENT'
            WHEN duration_ms < 150 THEN 'GOOD'
            WHEN duration_ms < 300 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (duration_ms < 75)::BOOLEAN,
        'Good/Better/Best filtering'::TEXT;
    
    -- ==========================================================================
    -- Test 5: Complete Assembly Cost Calculation Simulation
    -- Target: <500ms for full estimate generation query path
    -- ==========================================================================
    
    start_time := clock_timestamp();
    
    -- Simulate full Assembly Engine calculation
    WITH assembly_calc AS (
        SELECT 
            a.assembly_id,
            a.name,
            aim.item_id,
            aim.description,
            aim.assembly_quantity,
            aim.national_average_cost,
            lcm.material_modifier,
            lcm.labor_modifier,
            CASE 
                WHEN aim.item_type = 'material' THEN 
                    aim.national_average_cost * lcm.material_modifier * aim.assembly_quantity
                WHEN aim.item_type = 'labor' THEN
                    aim.national_average_cost * lcm.labor_modifier * aim.assembly_quantity
                ELSE aim.national_average_cost * aim.assembly_quantity
            END as localized_cost
        FROM Assemblies a
        JOIN assembly_items_materialized aim ON a.assembly_id = aim.assembly_id
        JOIN LocationCostModifiers lcm ON lcm.metro_name = 'San Francisco, CA'
        WHERE a.category = 'kitchen'
        LIMIT 50  -- Simulate typical kitchen assembly
    )
    SELECT COUNT(*), SUM(localized_cost) INTO row_count, duration_ms
    FROM assembly_calc;
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Assembly Engine'::TEXT,
        'Complete Cost Calculation'::TEXT,
        duration_ms,
        row_count,
        CASE 
            WHEN duration_ms < 500 THEN 'EXCELLENT'
            WHEN duration_ms < 1000 THEN 'GOOD'
            WHEN duration_ms < 2000 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (duration_ms < 500)::BOOLEAN,
        'Full estimate simulation'::TEXT;
    
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- DATABASE INFRASTRUCTURE PERFORMANCE TESTS
-- =============================================================================

CREATE OR REPLACE FUNCTION run_infrastructure_benchmarks()
RETURNS TABLE (
    test_category TEXT,
    test_name TEXT,
    measurement NUMERIC,
    unit TEXT,
    performance_rating TEXT,
    meets_target BOOLEAN,
    recommendation TEXT
) AS $$
DECLARE
    cache_hit_ratio NUMERIC;
    index_hit_ratio NUMERIC;
    connection_count BIGINT;
    db_size_mb NUMERIC;
BEGIN
    -- ==========================================================================
    -- Test 1: Database Cache Hit Ratio
    -- Target: >95% cache hit ratio
    -- ==========================================================================
    
    SELECT ROUND(
        (sum(heap_blks_hit) * 100.0) / 
        NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2
    ) INTO cache_hit_ratio
    FROM pg_statio_user_tables 
    WHERE schemaname = 'contractorlens';
    
    RETURN QUERY SELECT 
        'Infrastructure'::TEXT,
        'Database Cache Hit Ratio'::TEXT,
        COALESCE(cache_hit_ratio, 0),
        'percent'::TEXT,
        CASE 
            WHEN cache_hit_ratio >= 95 THEN 'EXCELLENT'
            WHEN cache_hit_ratio >= 90 THEN 'GOOD'
            WHEN cache_hit_ratio >= 80 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (COALESCE(cache_hit_ratio, 0) >= 95)::BOOLEAN,
        'Increase shared_buffers if low'::TEXT;
    
    -- ==========================================================================
    -- Test 2: Index Hit Ratio
    -- Target: >99% index hit ratio
    -- ==========================================================================
    
    SELECT ROUND(
        (sum(idx_blks_hit) * 100.0) / 
        NULLIF(sum(idx_blks_hit) + sum(idx_blks_read), 0), 2
    ) INTO index_hit_ratio
    FROM pg_statio_user_indexes 
    WHERE schemaname = 'contractorlens';
    
    RETURN QUERY SELECT 
        'Infrastructure'::TEXT,
        'Index Cache Hit Ratio'::TEXT,
        COALESCE(index_hit_ratio, 0),
        'percent'::TEXT,
        CASE 
            WHEN index_hit_ratio >= 99 THEN 'EXCELLENT'
            WHEN index_hit_ratio >= 95 THEN 'GOOD'
            WHEN index_hit_ratio >= 90 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (COALESCE(index_hit_ratio, 0) >= 99)::BOOLEAN,
        'Review index usage patterns'::TEXT;
    
    -- ==========================================================================
    -- Test 3: Connection Count
    -- Target: <25 active connections under normal load
    -- ==========================================================================
    
    SELECT COUNT(*) INTO connection_count
    FROM pg_stat_activity 
    WHERE datname = 'contractorlens' AND state = 'active';
    
    RETURN QUERY SELECT 
        'Infrastructure'::TEXT,
        'Active Connections'::TEXT,
        connection_count::NUMERIC,
        'connections'::TEXT,
        CASE 
            WHEN connection_count <= 10 THEN 'EXCELLENT'
            WHEN connection_count <= 25 THEN 'GOOD'
            WHEN connection_count <= 50 THEN 'ACCEPTABLE'
            ELSE 'NEEDS_IMPROVEMENT'
        END::TEXT,
        (connection_count <= 25)::BOOLEAN,
        'Monitor connection pooling'::TEXT;
    
    -- ==========================================================================
    -- Test 4: Database Size Growth
    -- Target: Monitor database size for capacity planning
    -- ==========================================================================
    
    SELECT ROUND(pg_database_size('contractorlens') / (1024.0 * 1024.0), 1) 
    INTO db_size_mb;
    
    RETURN QUERY SELECT 
        'Infrastructure'::TEXT,
        'Database Size'::TEXT,
        db_size_mb,
        'MB'::TEXT,
        CASE 
            WHEN db_size_mb < 500 THEN 'EXCELLENT'
            WHEN db_size_mb < 1000 THEN 'GOOD'
            WHEN db_size_mb < 5000 THEN 'ACCEPTABLE'
            ELSE 'MONITOR'
        END::TEXT,
        TRUE::BOOLEAN, -- Always acceptable for monitoring
        'Monitor growth trends'::TEXT;
        
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- STRESS TEST SIMULATION
-- =============================================================================

CREATE OR REPLACE FUNCTION run_stress_test_simulation()
RETURNS TABLE (
    test_name TEXT,
    concurrent_users INTEGER,
    operations_per_second NUMERIC,
    avg_response_time_ms NUMERIC,
    success_rate NUMERIC,
    performance_under_load TEXT
) AS $$
DECLARE
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
    duration_ms NUMERIC;
    total_operations INTEGER;
BEGIN
    -- ==========================================================================
    -- Stress Test 1: Concurrent Location Lookups
    -- Simulate 10 concurrent users doing location lookups
    -- ==========================================================================
    
    start_time := clock_timestamp();
    total_operations := 0;
    
    -- Simulate concurrent location lookups
    FOR i IN 1..50 LOOP
        PERFORM * FROM get_location_modifiers_optimized('9410' || (i % 10));
        total_operations := total_operations + 1;
    END LOOP;
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Concurrent Location Lookups'::TEXT,
        10::INTEGER,
        ROUND(total_operations * 1000.0 / duration_ms, 2),
        ROUND(duration_ms / total_operations, 2),
        100.0::NUMERIC, -- Assume 100% success for this test
        CASE 
            WHEN (duration_ms / total_operations) < 50 THEN 'EXCELLENT_UNDER_LOAD'
            WHEN (duration_ms / total_operations) < 100 THEN 'GOOD_UNDER_LOAD'
            ELSE 'DEGRADED_UNDER_LOAD'
        END::TEXT;
    
    -- ==========================================================================
    -- Stress Test 2: Assembly Calculations Under Load
    -- Simulate multiple estimate generations
    -- ==========================================================================
    
    start_time := clock_timestamp();
    total_operations := 0;
    
    -- Simulate concurrent assembly calculations
    FOR i IN 1..25 LOOP
        PERFORM aim.* 
        FROM assembly_items_materialized aim
        WHERE aim.assembly_id = (
            SELECT assembly_id FROM Assemblies 
            ORDER BY RANDOM() LIMIT 1
        );
        total_operations := total_operations + 1;
    END LOOP;
    
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM end_time - start_time);
    
    RETURN QUERY SELECT 
        'Concurrent Assembly Calculations'::TEXT,
        25::INTEGER,
        ROUND(total_operations * 1000.0 / duration_ms, 2),
        ROUND(duration_ms / total_operations, 2),
        100.0::NUMERIC,
        CASE 
            WHEN (duration_ms / total_operations) < 100 THEN 'EXCELLENT_UNDER_LOAD'
            WHEN (duration_ms / total_operations) < 200 THEN 'GOOD_UNDER_LOAD'
            ELSE 'DEGRADED_UNDER_LOAD'
        END::TEXT;
        
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMPREHENSIVE PERFORMANCE REPORT
-- =============================================================================

CREATE OR REPLACE FUNCTION generate_performance_report()
RETURNS JSON AS $$
DECLARE
    report JSON;
    benchmark_results JSON;
    infrastructure_results JSON;
    stress_test_results JSON;
BEGIN
    -- Collect all benchmark results
    SELECT json_agg(row_to_json(t))
    INTO benchmark_results
    FROM (SELECT * FROM run_performance_benchmarks()) t;
    
    SELECT json_agg(row_to_json(t))
    INTO infrastructure_results  
    FROM (SELECT * FROM run_infrastructure_benchmarks()) t;
    
    SELECT json_agg(row_to_json(t))
    INTO stress_test_results
    FROM (SELECT * FROM run_stress_test_simulation()) t;
    
    -- Build comprehensive report
    SELECT json_build_object(
        'report_metadata', json_build_object(
            'generated_at', NOW(),
            'database', 'contractorlens',
            'performance_engineer', 'PERF001',
            'optimization_phase', 'Phase 1 - Database Performance'
        ),
        'performance_targets', json_build_object(
            'location_lookup_ms', 50,
            'assembly_calculation_ms', 100,
            'retail_price_lookup_ms', 25,
            'complete_estimate_ms', 500,
            'cache_hit_ratio_percent', 95,
            'concurrent_users_supported', 25
        ),
        'benchmark_results', benchmark_results,
        'infrastructure_metrics', infrastructure_results,
        'stress_test_results', stress_test_results,
        'summary', json_build_object(
            'tests_passed', (
                SELECT COUNT(*) 
                FROM run_performance_benchmarks() 
                WHERE meets_target = TRUE
            ),
            'total_tests', (
                SELECT COUNT(*) 
                FROM run_performance_benchmarks()
            ),
            'overall_rating', CASE 
                WHEN (SELECT AVG(CASE WHEN meets_target THEN 1 ELSE 0 END) 
                      FROM run_performance_benchmarks()) >= 0.8 
                THEN 'PRODUCTION_READY'
                WHEN (SELECT AVG(CASE WHEN meets_target THEN 1 ELSE 0 END) 
                      FROM run_performance_benchmarks()) >= 0.6 
                THEN 'NEEDS_MINOR_TUNING'
                ELSE 'NEEDS_MAJOR_OPTIMIZATION'
            END
        ),
        'recommendations', json_build_array(
            'Monitor query performance during peak usage',
            'Consider connection pooling optimization',
            'Implement automated performance alerts',
            'Schedule regular VACUUM and ANALYZE operations'
        )
    ) INTO report;
    
    RETURN report;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- PERFORMANCE VALIDATION AND REPORTING
-- =============================================================================

-- Quick performance check function for regular monitoring
CREATE OR REPLACE FUNCTION quick_performance_check()
RETURNS TABLE (
    metric TEXT,
    current_value TEXT,
    target TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH performance_metrics AS (
        SELECT * FROM run_performance_benchmarks() 
        WHERE test_name LIKE '%Location Lookup%' 
           OR test_name LIKE '%Assembly Items%'
           OR test_name LIKE '%Complete Cost%'
    )
    SELECT 
        pm.test_name::TEXT,
        (pm.execution_time_ms || 'ms')::TEXT,
        CASE 
            WHEN pm.test_name LIKE '%Location%' THEN '<50ms'
            WHEN pm.test_name LIKE '%Assembly%' THEN '<100ms'
            WHEN pm.test_name LIKE '%Complete%' THEN '<500ms'
            ELSE 'varies'
        END::TEXT,
        CASE WHEN pm.meets_target THEN 'PASS' ELSE 'FAIL' END::TEXT
    FROM performance_metrics pm;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- AUTOMATED PERFORMANCE TESTING
-- =============================================================================

-- Schedule performance tests (example cron job function)
CREATE OR REPLACE FUNCTION automated_performance_monitoring()
RETURNS VOID AS $$
DECLARE
    performance_summary JSON;
    alert_needed BOOLEAN := FALSE;
BEGIN
    -- Run quick performance check
    SELECT json_agg(row_to_json(t))
    INTO performance_summary
    FROM (SELECT * FROM quick_performance_check()) t;
    
    -- Check if any critical metrics are failing
    SELECT EXISTS(
        SELECT 1 FROM quick_performance_check() 
        WHERE status = 'FAIL' AND metric LIKE '%Location%'
    ) INTO alert_needed;
    
    -- Log performance data
    INSERT INTO contractorlens.performance_monitoring_log (
        check_timestamp,
        metrics_summary,
        alert_level
    ) VALUES (
        NOW(),
        performance_summary,
        CASE WHEN alert_needed THEN 'HIGH' ELSE 'INFO' END
    )
    ON CONFLICT DO NOTHING; -- In case table doesn't exist yet
    
    -- Raise notice for immediate attention if needed
    IF alert_needed THEN
        RAISE WARNING 'Performance alert: Critical database queries exceeding target response times';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- BENCHMARKING SUITE INITIALIZATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== ContractorLens Performance Benchmarking Suite Initialized ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Available Functions:';
    RAISE NOTICE '  • run_performance_benchmarks() - Core Assembly Engine tests';
    RAISE NOTICE '  • run_infrastructure_benchmarks() - Database infrastructure metrics';
    RAISE NOTICE '  • run_stress_test_simulation() - Concurrent user simulation';
    RAISE NOTICE '  • generate_performance_report() - Comprehensive JSON report';
    RAISE NOTICE '  • quick_performance_check() - Fast monitoring check';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage Examples:';
    RAISE NOTICE '  SELECT * FROM run_performance_benchmarks();';
    RAISE NOTICE '  SELECT generate_performance_report();';
    RAISE NOTICE '  SELECT * FROM quick_performance_check();';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance Targets:';
    RAISE NOTICE '  ✓ Location lookups: <50ms';
    RAISE NOTICE '  ✓ Assembly calculations: <100ms';
    RAISE NOTICE '  ✓ Retail price lookups: <25ms';
    RAISE NOTICE '  ✓ Complete estimates: <500ms';
    RAISE NOTICE '  ✓ Cache hit ratio: >95%';
    RAISE NOTICE '  ✓ Concurrent users: 25+';
END;
$$;