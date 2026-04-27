-- 1. Indices for public.bracket_matches
-- Covers tournament_id_fkey, match_id_fkey, and next_match_id_fkey
CREATE INDEX IF NOT EXISTS idx_bracket_matches_tournament_id ON public.bracket_matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_bracket_matches_match_id ON public.bracket_matches(match_id);
CREATE INDEX IF NOT EXISTS idx_bracket_matches_next_match_id ON public.bracket_matches(next_match_id);

-- 2. Index for public.match_events
-- Covers match_events_match_id_fkey
CREATE INDEX IF NOT EXISTS idx_match_events_match_id ON public.match_events(match_id);

-- 3. Indices for public.matches
-- Covers matches_organizer_id_fkey and matches_umpire_id_fkey
CREATE INDEX IF NOT EXISTS idx_matches_organizer_id ON public.matches(organizer_id);
CREATE INDEX IF NOT EXISTS idx_matches_umpire_id ON public.matches(umpire_id);

-- 4. Index for public.notifications
-- Covers notifications_user_id_fkey
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);

-- 5. Index for public.tournament_participants
-- Covers tournament_participants_tournament_id_fkey
CREATE INDEX IF NOT EXISTS idx_tournament_participants_tournament_id ON public.tournament_participants(tournament_id);

-- 6. Index for public.tournaments
-- Covers tournaments_organizer_id_fkey
CREATE INDEX IF NOT EXISTS idx_tournaments_organizer_id ON public.tournaments(organizer_id);
