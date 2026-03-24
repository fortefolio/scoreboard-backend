-- Add tennis-specific tracking if not already there
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS current_game_points INTEGER[] DEFAULT '{0,0}',
ADD COLUMN IF NOT EXISTS set_scores JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS tennis_points INTEGER[] DEFAULT '{0,0}',
ADD COLUMN IF NOT EXISTS tennis_games INTEGER[] DEFAULT '{0,0}',
ADD COLUMN IF NOT EXISTS current_set_index INTEGER DEFAULT 0;