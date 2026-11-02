-- Migration: 20261102180000_phase1_phase2_security_remediation.sql
-- Purpose:
--   Implements Phase 1 & Phase 2 Security Remediation:
--   1. Fix matches-rls-update-missing-tournament-ownership-check (Phase 1, High)
--   2. Fix matches-rls-umpire-unrestricted-column-update (Phase 2, Medium)
--   3. Fix backend-matches-scores-bypass (Phase 2, Medium - Option 2A RPC-only score authority)
--   4. Fix backend-matches-umpire-pending-auth (Phase 2, Medium)
--   5. Fix backend-rpc-atomic-scoring-preauth-idempotency-leak (Phase 2, Medium)

BEGIN;

-- ============================================================================
-- 1. Hardening public.matches UPDATE Policies & Ownership Constraints
-- ============================================================================

-- Drop prior UPDATE policies
DROP POLICY IF EXISTS "Organizers can update their matches" ON public.matches;
DROP POLICY IF EXISTS "Accepted umpires can update matches" ON public.matches;
DROP POLICY IF EXISTS "Organizers and Umpires can update matches" ON public.matches;

-- Organizers can only update their matches if tournament_id is either NULL or owned by the organizer
CREATE POLICY "Organizers can update their matches"
ON public.matches FOR UPDATE
USING (organizer_id = (SELECT auth.uid()))
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

-- Note: Umpires do NOT have direct table UPDATE on public.matches.
-- Umpires score via record_match_event_atomic and start_match_scoreboard,
-- which are SECURITY DEFINER functions. Umpires accept/refuse invitations via
-- accept_umpire_invitation and refuse_umpire_invitation.

-- ============================================================================
-- 2. Triggers for Structural & Ownership Immutability and Score Protection
-- ============================================================================

-- A. Tournament Ownership Check Trigger
CREATE OR REPLACE FUNCTION public.check_match_tournament_ownership()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tournament_id IS NOT NULL AND (OLD.tournament_id IS DISTINCT FROM NEW.tournament_id) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tournaments t
      WHERE t.id = NEW.tournament_id
      AND t.organizer_id = (SELECT auth.uid())
    ) THEN
      RAISE EXCEPTION 'Cannot associate match with a tournament not owned by caller';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS tr_check_match_tournament_ownership ON public.matches;
CREATE TRIGGER tr_check_match_tournament_ownership
BEFORE UPDATE OF tournament_id ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.check_match_tournament_ownership();

-- B. Harden check_match_organizer_immutable with search_path = ''
CREATE OR REPLACE FUNCTION public.check_match_organizer_immutable()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.organizer_id IS DISTINCT FROM OLD.organizer_id THEN
    IF auth.uid() IS NULL OR auth.uid() != OLD.organizer_id THEN
      RAISE EXCEPTION 'Only the match organizer can change the organizer_id';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- C. Score & Status Mutation Guard (Option 2A: Scoring Engine Integrity)
CREATE OR REPLACE FUNCTION public.check_match_score_and_status_mutation()
RETURNS TRIGGER AS $$
BEGIN
  -- When executed under the direct context of authenticated or anon roles (e.g. PostgREST PATCH)
  IF current_user = 'authenticated' OR current_user = 'anon' THEN
    -- Prohibit direct mutation of scores column
    IF NEW.scores IS DISTINCT FROM OLD.scores THEN
      RAISE EXCEPTION 'Direct score mutation is prohibited. All scoring must use record_match_event_atomic.';
    END IF;

    -- Prohibit direct completion of matches (must use finalize-match or atomic scoring RPC)
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
      RAISE EXCEPTION 'Matches can only be marked completed via finalize-match or atomic scoring RPC.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS tr_check_match_score_and_status_mutation ON public.matches;
CREATE TRIGGER tr_check_match_score_and_status_mutation
BEFORE UPDATE OF scores, status ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.check_match_score_and_status_mutation();

-- ============================================================================
-- 3. Require Accepted Umpire Status in start_match_scoreboard & update_tennis_score
-- ============================================================================

CREATE OR REPLACE FUNCTION public.start_match_scoreboard(
    m_id UUID,
    initial_server_index INTEGER DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    v_scores JSONB;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = m_id
        AND (
          organizer_id = (SELECT auth.uid()) 
          OR (umpire_id = (SELECT auth.uid()) AND umpire_invite_status = 'accepted')
        )
    ) THEN
        RAISE EXCEPTION 'Not authorized to start this match scoreboard';
    END IF;

    SELECT COALESCE(scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb)
    INTO v_scores
    FROM public.matches
    WHERE id = m_id;

    IF initial_server_index IS NOT NULL THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', initial_server_index::TEXT::jsonb);
    END IF;

    UPDATE public.matches
    SET
        status = 'ongoing',
        scores = v_scores,
        updated_at = pg_catalog.now()
    WHERE id = m_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.update_tennis_score(m_id UUID, winner_idx INT)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = m_id
        AND (
          organizer_id = (SELECT auth.uid()) 
          OR (umpire_id = (SELECT auth.uid()) AND umpire_invite_status = 'accepted')
        )
    ) THEN
        RAISE EXCEPTION 'Not authorized to update score for this match';
    END IF;

    INSERT INTO public.match_events (match_id, event_data)
    VALUES (
        m_id,
        jsonb_build_object(
            'type', 'point_won',
            'winner_index', winner_idx,
            'timestamp', pg_catalog.now()
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ============================================================================
-- 4. Re-order Authorization and Idempotency in record_match_event_atomic
-- ============================================================================

CREATE OR REPLACE FUNCTION public.record_match_event_atomic(
  p_match_id uuid,
  p_idempotency_key uuid,
  p_new_scores jsonb,
  p_event_data jsonb,
  p_new_status match_status DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_updated_match jsonb;
  v_user_id uuid;
BEGIN
  -- A. Authorization Guard: Only match organizer, accepted umpire or service_role can score
  IF current_setting('role', true) != 'service_role' THEN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.matches 
      WHERE id = p_match_id 
        AND (
          organizer_id = v_user_id 
          OR (umpire_id = v_user_id AND umpire_invite_status = 'accepted')
        )
    ) THEN
      RAISE EXCEPTION 'Unauthorized to score this match';
    END IF;
  END IF;

  -- B. Idempotency Guard: Only after authorization passes
  IF p_idempotency_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.match_events WHERE idempotency_key = p_idempotency_key
  ) THEN
    SELECT to_jsonb(m) INTO v_updated_match FROM public.matches m WHERE id = p_match_id;
    RETURN v_updated_match;
  END IF;

  -- C. Insert Immutable Event Log
  INSERT INTO public.match_events (match_id, idempotency_key, event_data)
  VALUES (p_match_id, p_idempotency_key, p_event_data);

  -- D. Update Match Scoreboard Atomically
  UPDATE public.matches
  SET 
    scores = COALESCE(p_new_scores, scores),
    status = COALESCE(p_new_status, status),
    updated_at = pg_catalog.now()
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_updated_match;

  -- E. Realtime Broadcast directly from PostgreSQL to all connected spectators
  BEGIN
    PERFORM realtime.send(
      jsonb_build_object(
        'match_id', p_match_id,
        'scores', COALESCE(p_new_scores, v_updated_match->'scores'),
        'status', v_updated_match->>'status',
        'event_data', p_event_data
      ),
      'score_update',
      'match:' || p_match_id::text,
      false
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN v_updated_match;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO service_role;

COMMIT;
