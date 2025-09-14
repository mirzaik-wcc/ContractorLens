-- Seed data for LaborTasks table

-- This links specific labor items to their detailed task breakdown.
-- Note: The item_id needs to correspond to an actual 'labor' item in the Items table.

-- Example for Drywall Installation Labor
INSERT INTO LaborTasks (item_id, task_name, base_production_rate, crew_size, skill_level, setup_time_hours, cleanup_time_hours)
SELECT item_id, 'Install 1/2" Gypsum Board', 0.016, 2, 'journeyman', 0.5, 1.0
FROM Items WHERE csi_code = '09 29 00' AND item_type = 'labor' LIMIT 1;

-- Example for Interior Painting Labor
INSERT INTO LaborTasks (item_id, task_name, base_production_rate, crew_size, skill_level, setup_time_hours, cleanup_time_hours)
SELECT item_id, 'Apply Two Coats of Latex Paint', 0.008, 1, 'journeyman', 1.0, 0.75
FROM Items WHERE csi_code = '09 91 23' AND item_type = 'labor' LIMIT 1;

-- Example for Ceramic Tile Flooring Labor
INSERT INTO LaborTasks (item_id, task_name, base_production_rate, crew_size, skill_level, setup_time_hours, cleanup_time_hours)
SELECT item_id, 'Install 12x12 Ceramic Floor Tile', 0.08, 1, 'master', 1.5, 1.0
FROM Items WHERE csi_code = '09 30 13' AND item_type = 'labor' LIMIT 1;
