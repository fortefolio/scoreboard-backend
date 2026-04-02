-- 0. Drop dependent views to allow column changes
DROP VIEW IF EXISTS public.user_feed;
DROP VIEW IF EXISTS public.group_standings;

-- 1. Add the generic scores column
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS scores JSONB DEFAULT '{}'::jsonb;

-- 2. Migrate existing data into the unified scores structure
UPDATE public.matches
SET scores = jsonb_build_object(
    -- Common score (previously current_score)
    'current', current_score,
    -- Tennis specific data
    'tennis', CASE 
        WHEN sport_type = 'tennis' THEN 
            jsonb_build_object(
                'points', tennis_points,
                'games', tennis_games,
                'sets', set_scores,
                'current_set', current_set_index
            )
        ELSE NULL 
    END,
    -- Serving info
    'serving_index', serving_index
);

-- 3. Drop the redundant fragmented columns
ALTER TABLE public.matches 
DROP COLUMN IF EXISTS tennis_points,
DROP COLUMN IF EXISTS tennis_games,
DROP COLUMN IF EXISTS current_game_points,
DROP COLUMN IF EXISTS set_scores,
DROP COLUMN IF EXISTS current_set_index,
DROP COLUMN IF EXISTS serving_index,
DROP COLUMN IF EXISTS current_score;

-- 4. Enable Supabase Real-time for the matches table
-- First, ensure the publication exists (Supabase default)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Add matches to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;

-- Add a comment for documentation
COMMENT ON COLUMN public.matches.scores IS 'Unified sport-specific scoring: { "current": {}, "tennis": { "points": [], ... }, "serving_index": 0 }';
