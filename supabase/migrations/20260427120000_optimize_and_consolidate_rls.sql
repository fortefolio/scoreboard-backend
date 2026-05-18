-- Performance and Redundancy Cleanup for RLS Policies
-- This migration resolves "Auth RLS Initialization Plan" (performance) 
-- and "Multiple Permissive Policies" (redundancy) lint warnings.

BEGIN;

-- ==========================================
-- 1. public.matches
-- ==========================================

DROP POLICY IF EXISTS "Organizers can insert matches" ON public.matches;
DROP POLICY IF EXISTS "Organizers can update their matches" ON public.matches;
DROP POLICY IF EXISTS "Matches visibility policy" ON public.matches;

-- Consolidated SELECT: Follows tournament visibility
CREATE POLICY "Matches visibility policy"
ON public.matches FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = (SELECT auth.uid()))
    )
    OR (tournament_id IS NULL)
);

CREATE POLICY "Organizers can insert matches" 
ON public.matches FOR INSERT 
WITH CHECK (organizer_id = (SELECT auth.uid()));

-- Consolidated UPDATE: Allows Organizer OR Umpire
CREATE POLICY "Organizers and Umpires can update matches" 
ON public.matches FOR UPDATE 
USING (
  organizer_id = (SELECT auth.uid()) OR 
  umpire_id = (SELECT auth.uid())
)
WITH CHECK (
  organizer_id = (SELECT auth.uid()) OR 
  umpire_id = (SELECT auth.uid())
);


-- ==========================================
-- 2. public.tournaments
-- ==========================================

DROP POLICY IF EXISTS "Only Pro users can create tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Organizers can create their own tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Organizers can update their tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Organizers can delete their own tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "Tournaments visibility policy" ON public.tournaments;
DROP POLICY IF EXISTS "Organizers can view their own tournaments" ON public.tournaments;

-- Consolidated SELECT: Follows visibility settings
CREATE POLICY "Tournaments visibility policy"
ON public.tournaments FOR SELECT
USING (
    visibility = 'public' 
    OR visibility = 'unlisted' 
    OR organizer_id = (SELECT auth.uid())
);

-- Consolidated INSERT: Requires Pro tier AND matching organizer_id
CREATE POLICY "Pro users can create their own tournaments"
ON public.tournaments FOR INSERT
WITH CHECK (
    organizer_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = (SELECT auth.uid()) 
        AND subscription_tier = 'pro'
    )
);

CREATE POLICY "Organizers can update their tournaments" 
ON public.tournaments FOR UPDATE 
USING (organizer_id = (SELECT auth.uid()));

CREATE POLICY "Organizers can delete their own tournaments"
ON public.tournaments FOR DELETE
USING (organizer_id = (SELECT auth.uid()));


-- ==========================================
-- 3. public.match_events
-- ==========================================

DROP POLICY IF EXISTS "Match events visibility policy" ON public.match_events;
DROP POLICY IF EXISTS "Only match organizers can insert events" ON public.match_events;

CREATE POLICY "Match events visibility policy"
ON public.match_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON t.id = m.tournament_id
        WHERE m.id = match_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = (SELECT auth.uid()))
    )
    OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE m.id = match_id
        AND m.tournament_id IS NULL
    )
);

CREATE POLICY "Only match organizers can insert events" 
ON public.match_events FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.matches 
        WHERE id = match_id 
        AND (organizer_id = (SELECT auth.uid()) OR umpire_id = (SELECT auth.uid()))
    )
);


-- ==========================================
-- 4. public.notifications
-- ==========================================

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;

CREATE POLICY "Users can manage their own notifications"
ON public.notifications FOR ALL
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));


-- ==========================================
-- 5. public.follows
-- ==========================================

DROP POLICY IF EXISTS "Users can view their own follows" ON public.follows;
DROP POLICY IF EXISTS "Users can manage their own follows" ON public.follows;

CREATE POLICY "Users can manage their own follows"
ON public.follows FOR ALL
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));


-- ==========================================
-- 6. public.bracket_matches
-- ==========================================

DROP POLICY IF EXISTS "Bracket matches visibility policy" ON public.bracket_matches;
DROP POLICY IF EXISTS "Organizers can manage bracket matches" ON public.bracket_matches;

CREATE POLICY "Bracket matches visibility policy"
ON public.bracket_matches FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = (SELECT auth.uid()))
    )
);

-- Allow organizers to manage bracket matches (Write operations only)
CREATE POLICY "Organizers can insert bracket matches"
ON public.bracket_matches FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Organizers can update bracket matches"
ON public.bracket_matches FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Organizers can delete bracket matches"
ON public.bracket_matches FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    )
);


-- ==========================================
-- 7. public.user_tokens
-- ==========================================

DROP POLICY IF EXISTS "Users can manage their own tokens" ON public.user_tokens;

CREATE POLICY "Users can manage their own tokens"
ON public.user_tokens FOR ALL
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

COMMIT;
