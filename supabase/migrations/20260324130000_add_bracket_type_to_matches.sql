-- Add bracket_type to distinguish between different bracket segments (e.g., 'main', 'losers', 'grand_final')
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS bracket_type TEXT DEFAULT 'main';

-- Create an index for faster filtering by bracket type within a tournament
CREATE INDEX idx_matches_tournament_bracket_type ON public.matches(tournament_id, bracket_type);