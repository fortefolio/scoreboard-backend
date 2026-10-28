-- ============================================================================
-- Migration: 20260522060000_security_audit_hardening.sql
-- Purpose:
--   Remediate vulnerabilities identified during the security audit:
--   1. Prevent match ownership takeover by umpires.
--   2. Require umpire_invite_status = 'accepted' for match edits and match_events.
--   3. Prevent inserting matches into third-party tournaments.
--   4. Prevent unauthorized direct notification inserts.
--   5. Protect user PII (email) on public.users and add secure search_umpires RPC.
--   6. Secure search_path on critical SECURITY DEFINER functions.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Hardening public.matches RLS Policies
-- ============================================================================

DROP POLICY IF EXISTS "Organizers and Umpires can update matches" ON public.matches;
DROP POLICY IF EXISTS "Organizers can update matches" ON public.matches;
DROP POLICY IF EXISTS "Organizers can update their matches" ON public.matches;
DROP POLICY IF EXISTS "Umpires can update matches" ON public.matches;
DROP POLICY IF EXISTS "Accepted umpires can update matches" ON public.matches;

-- Organizers can update their own matches (including assigning an umpire)
CREATE POLICY "Organizers can update their matches"
ON public.matches FOR UPDATE
USING (organizer_id = (SELECT auth.uid()))
WITH CHECK (organizer_id = (SELECT auth.uid()));

-- Only accepted umpires can update match fields, and CANNOT change organizer_id
CREATE POLICY "Accepted umpires can update matches"
ON public.matches FOR UPDATE
USING (
  umpire_id = (SELECT auth.uid()) 
  AND umpire_invite_status = 'accepted'
)
WITH CHECK (
  umpire_id = (SELECT auth.uid()) 
  AND umpire_invite_status = 'accepted'
  AND organizer_id = (SELECT m.organizer_id FROM public.matches m WHERE m.id = matches.id)
);

-- Fix match creation: Prevent linking to other organizers' tournaments
DROP POLICY IF EXISTS "Organizers can insert matches" ON public.matches;

CREATE POLICY "Organizers can insert matches"
ON public.matches FOR INSERT
WITH CHECK (
  organizer_id = (SELECT auth.uid())
  AND (
    tournament_id IS NULL 
    OR EXISTS (
      SELECT 1 FROM public.tournaments t 
      WHERE t.id = tournament_id 
      AND t.organizer_id = (SELECT auth.uid())
    )
  )
);


-- ============================================================================
-- 2. Hardening public.match_events RLS Policies
-- ============================================================================

DROP POLICY IF EXISTS "Only match organizers can insert events" ON public.match_events;
DROP POLICY IF EXISTS "Only match organizers and accepted umpires can insert events" ON public.match_events;

CREATE POLICY "Only match organizers and accepted umpires can insert events"
ON public.match_events FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.matches 
    WHERE id = match_id 
    AND (
      organizer_id = (SELECT auth.uid()) 
      OR (umpire_id = (SELECT auth.uid()) AND umpire_invite_status = 'accepted')
    )
  )
);


-- ============================================================================
-- 3. Hardening public.notifications RLS Policies
-- ============================================================================
-- Users should only read, mark read (update), and delete their own notifications.
-- Direct INSERT from clients is restricted so malicious clients cannot trigger FCM abuse.

DROP POLICY IF EXISTS "Users can manage their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;

CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT
USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can delete their own notifications"
ON public.notifications FOR DELETE
USING (user_id = (SELECT auth.uid()));


-- ============================================================================
-- 4. Protect User PII (email) and provide search_umpires RPC
-- ============================================================================

REVOKE SELECT ON public.users FROM authenticated;
GRANT SELECT (id, username, subscription_tier, created_at, updated_at) ON public.users TO authenticated;

-- Secure function to search umpires without dumping full email list
CREATE OR REPLACE FUNCTION public.search_umpires(p_query TEXT)
RETURNS TABLE (
  id UUID, 
  username TEXT
) AS $$
BEGIN
  IF length(trim(coalesce(p_query, ''))) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT u.id, u.username
  FROM public.users u
  WHERE u.username ILIKE '%' || p_query || '%'
     OR u.email ILIKE '%' || p_query || '%'
  LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.search_umpires(TEXT) TO authenticated;


-- ============================================================================
-- 5. Secure Function search_path on Critical Definier Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION public.accept_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.matches 
    SET umpire_invite_status = 'accepted'
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    UPDATE public.notifications
    SET read_at = pg_catalog.now()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.refuse_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.matches 
    SET umpire_invite_status = 'refused',
        umpire_id = NULL
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    UPDATE public.notifications
    SET read_at = pg_catalog.now()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

COMMIT;
