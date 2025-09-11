-- Seed data for Trades table
-- Follows CSI MasterFormat for professional organization

INSERT INTO Trades (csi_division, division_name, trade_name, sort_order) VALUES
-- Division 01 - General Requirements
('01', 'General Requirements', 'Project Management', 1),
('01', 'General Requirements', 'Allowances', 2),
-- Division 02 - Existing Conditions  
('02', 'Existing Conditions', 'Demolition', 10),
('02', 'Existing Conditions', 'Site Remediation', 11),
-- Division 03 - Concrete
('03', 'Concrete', 'Concrete Forming', 20),
('03', 'Concrete', 'Concrete Reinforcing', 21),
-- Division 04 - Masonry
('04', 'Masonry', 'Unit Masonry', 30),
-- Division 05 - Metals
('05', 'Metals', 'Structural Metal Framing', 35),
-- Division 06 - Wood, Plastics, Composites
('06', 'Wood, Plastics, and Composites', 'Rough Carpentry', 40),
('06', 'Wood, Plastics, and Composites', 'Finish Carpentry', 41),
-- Division 07 - Thermal and Moisture Protection
('07', 'Thermal and Moisture Protection', 'Roofing', 50),
-- Division 08 - Openings
('08', 'Openings', 'Doors and Frames', 60),
('08', 'Openings', 'Windows', 61),
-- Division 09 - Finishes
('09', 'Finishes', 'Drywall', 70),
('09', 'Finishes', 'Tiling', 71),
('09', 'Finishes', 'Flooring', 72),
('09', 'Finishes', 'Painting', 73),
-- Division 21 - Fire Suppression
('21', 'Fire Suppression', 'Fire Sprinklers', 80),
-- Division 22 - Plumbing
('22', 'Plumbing', 'Plumbing Fixtures', 90),
-- Division 23 - HVAC
('23', 'HVAC', 'Ventilation', 100),
-- Division 26 - Electrical
('26', 'Electrical', 'Wiring and Devices', 110);
