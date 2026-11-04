-- ============================================================================
-- Migration: Atomic Scoring + In-Database Realtime Broadcast
-- File: supabase/migrations/20261104150200_atomic_score_and_broadcast.sql
-- Description:
--   1. Replaces record_match_event_atomic with partition-pruned idempotency checks.
--   2. Preserves strict RBAC authorization (organizer, accepted umpire, service_role).
--   3. Emits Postgres-level Supabase Realtime broadcast (bypassing per-subscriber WAL decode).
--   4. Supports backwards-compatible events for existing mobile and web clients.
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
SET search_path = public
AS $$
DECLARE
  v_updated_match jsonb;
  v_user_id uuid;
  v_broadcast_payload jsonb;
BEGIN
  -- 1. Authorization Guard: Only match organizer, accepted umpire or service_role can score
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
      RAISE EXCEPTION 'UNAUTHORIZED_SCORER: Only the assigned umpire or organizer can score this match.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 2. Partition-Pruned Idempotency Guard (looks back 24 hours to scan active partition only)
  IF p_idempotency_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.match_events 
    WHERE idempotency_key = p_idempotency_key
      AND created_at >= now() - interval '24 hours'
  ) THEN
    SELECT to_jsonb(m) INTO v_updated_match FROM public.matches m WHERE id = p_match_id;
    RETURN v_updated_match;
  END IF;

  -- 3. Insert point event into active partition
  INSERT INTO public.match_events (match_id, idempotency_key, event_data, created_at)
  VALUES (p_match_id, p_idempotency_key, p_event_data, now());

  -- 4. Atomically update match scoreboard
  UPDATE public.matches
  SET 
    scores = COALESCE(p_new_scores, scores),
    status = COALESCE(p_new_status, status),
    updated_at = now()
  WHERE id = p_match_id
  RETURNING to_jsonb(matches.*) INTO v_updated_match;

  -- 5. Prepare broadcast payload
  v_broadcast_payload := jsonb_build_object(
    'match_id', p_match_id,
    'scores', COALESCE(p_new_scores, v_updated_match->'scores'),
    'status', v_updated_match->>'status',
    'event_data', p_event_data
  );

  -- 6. Emit low-latency Supabase Realtime Broadcast directly from Postgres
  -- Broadcasts 'score_update' (current client standard) and 'SCORE_UPDATED' (scaling blueprint)
  BEGIN
    PERFORM realtime.send(
      v_broadcast_payload,
      'score_update',
      'match:' || p_match_id::text,
      false
    );
    PERFORM realtime.send(
      v_broadcast_payload,
      'SCORE_UPDATED',
      'match:' || p_match_id::text,
      false
    );
  EXCEPTION WHEN OTHERS THEN
    -- Prevent scoring rollback if realtime extension/schema is temporarily unavailable
    NULL;
  END;

  RETURN v_updated_match;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO service_role;
