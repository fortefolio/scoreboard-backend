-- No table changes needed, but let's document the new JSON structure
-- The 'settings' column will now support:
-- { 
--   "default": { "max_sets": 3, "points_per_set": 15, "point_cap": 17 },
--   "overrides": { "3": { "points_per_set": 25, "point_cap": 30 } }
-- }
COMMENT ON COLUMN public.tournaments.settings IS 'Stores max_sets, points_per_set, and optional point_cap';