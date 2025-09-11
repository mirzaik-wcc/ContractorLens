-- Seed data for MaterialSpecifications table

-- This links specific material items to their detailed specifications.
-- Note: The item_id needs to correspond to an actual 'material' item in the Items table.

-- Example for a specific type of Drywall
INSERT INTO MaterialSpecifications (item_id, manufacturer, model_number, brand_name, size_dimensions, weight)
SELECT item_id, 'USG', '222834', 'Sheetrock', '4 ft. x 8 ft. x 1/2 in.', 54.4
FROM Items WHERE csi_code = '09 29 00' AND item_type = 'material' AND description LIKE '%1/2" Gypsum Board%' LIMIT 1;

-- Example for a specific type of Paint
INSERT INTO MaterialSpecifications (item_id, manufacturer, model_number, brand_name, color_finish)
SELECT item_id, 'Sherwin-Williams', 'SW-7006', 'ProClassic', 'Pure White'
FROM Items WHERE csi_code = '09 91 23' AND item_type = 'material' AND description LIKE '%Interior Latex Paint%' LIMIT 1;

-- Example for a specific type of Ceramic Tile
INSERT INTO MaterialSpecifications (item_id, manufacturer, model_number, brand_name, size_dimensions, color_finish)
SELECT item_id, 'Daltile', 'X70112121P', 'Color Wheel Classic', '12 in. x 12 in.', 'White'
FROM Items WHERE csi_code = '09 30 13' AND item_type = 'material' AND description LIKE '%Ceramic Tile%' LIMIT 1;
