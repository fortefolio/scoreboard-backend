-- Add settings column to matches
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}'::jsonb;

-- Add a comment to describe the structure
COMMENT ON COLUMN public.matches.settings IS 'Stores match-specific rules: max_sets, points_per_set, and point_cap';
