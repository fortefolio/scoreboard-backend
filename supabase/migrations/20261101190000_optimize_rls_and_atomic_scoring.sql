-- Migration: 20261101190000_optimize_rls_and_atomic_scoring.sql
-- Hardens database performance, introduces composite event indices,
-- idempotency guards, and the atomic scoring RPC for high-concurrency environments.

-- 1. Composite Index for High-Frequency Timeline & Event Queries
CREATE INDEX IF NOT EXISTS idx_match_events_match_id_created 
ON public.match_events (match_id, created_at DESC);

-- 2. Idempotency Key to Prevent Duplicate Point Retries
ALTER TABLE public.match_events 
ADD COLUMN IF NOT EXISTS idempotency_key uuid UNIQUE;

-- 3. Atomic & Idempotent Scoring RPC
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
BEGIN
  -- A. Idempotency Guard: If this exact tap was already processed, return current state without error
  IF p_idempotency_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.match_events WHERE idempotency_key = p_idempotency_key
  ) THEN
    SELECT to_jsonb(m) INTO v_updated_match FROM public.matches m WHERE id = p_match_id;
    RETURN v_updated_match;
  END IF;

  -- B. Authorization Guard: Only match organizer, accepted umpire or service_role can score
  IF current_setting('role', true) != 'service_role' THEN
    IF auth.uid() IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.matches 
      WHERE id = p_match_id 
        AND (
          organizer_id = (SELECT auth.uid()) 
          OR (umpire_id = (SELECT auth.uid()) AND umpire_invite_status = 'accepted')
        )
    ) THEN
      RAISE EXCEPTION 'Unauthorized to score this match';
    END IF;
  END IF;

  -- C. Insert Immutable Event Log
  INSERT INTO public.match_events (match_id, idempotency_key, event_data)
  VALUES (p_match_id, p_idempotency_key, p_event_data);

  -- D. Update Match Scoreboard Atomically
  UPDATE public.matches
  SET 
    scores = COALESCE(p_new_scores, scores),
    status = COALESCE(p_new_status, status),
    updated_at = now()
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
    -- Fallback silently if realtime schema or topic is unavailable
    NULL;
  END;

  RETURN v_updated_match;
END;
$$;

-- Grant execution to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_match_event_atomic TO service_role;
