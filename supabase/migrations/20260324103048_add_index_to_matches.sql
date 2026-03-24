-- Create a composite index to speed up the "Find Next Match" logic
-- This covers tournament_id, round_number, and match_order in one search tree
CREATE INDEX IF NOT EXISTS idx_matches_tournament_round_order 
ON public.matches (tournament_id, round_number, match_order);

-- Performance Note: This makes the "Advance Winner" lookup O(log n) instead of O(n)