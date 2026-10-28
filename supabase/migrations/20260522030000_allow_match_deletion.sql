-- ============================================================================
-- Migration: 20260522030000_allow_match_deletion.sql
-- Purpose:
--   Allow authenticated organizers to delete standalone matches (tournament_id IS NULL)
--   that they created, as well as tournament organizers to delete matches within their tournaments.
-- ============================================================================

DROP POLICY IF EXISTS "Organizers can delete matches" ON public.matches;

CREATE POLICY "Organizers can delete matches" ON public.matches
FOR DELETE TO authenticated
USING (
  (tournament_id IS NULL AND organizer_id = (SELECT auth.uid()))
  OR
  (tournament_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.tournaments t
    WHERE t.id = matches.tournament_id
      AND t.organizer_id = (SELECT auth.uid())
  ))
);
