-- ============================================================================
-- Migration: Rate-Limiting Indexes, Advisory Locks & Creation Guards
-- File: supabase/migrations/20261104150000_rate_limit_guards.sql
-- Description:
--   1. Covering indexes on matches and tournaments for index-only scans on organizer timelines.
--   2. Advisory-locked, serialized rate limit trigger to prevent burst-creation race conditions.
-- ============================================================================

-- 1. Covering indexes to make rate-limit count checks instantaneous
CREATE INDEX IF NOT EXISTS idx_matches_organizer_created 
ON public.matches (organizer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tournaments_organizer_created 
ON public.tournaments (organizer_id, created_at DESC);

-- 2. Serialized, race-condition-proof rate limit guard for match creation
CREATE OR REPLACE FUNCTION public.check_match_creation_rate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recent_count integer;
  v_tier subscription_tier;
  v_max_per_minute integer;
BEGIN
  -- Bypass check if match has no organizer
  IF NEW.organizer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Acquire transaction-level advisory lock scoped to this specific organizer
  -- Prevents race conditions if a script fires parallel POST requests
  PERFORM pg_advisory_xact_lock(hashtext('match_rate_' || NEW.organizer_id::text));

  -- Check user's subscription tier (allow higher burst when generating tournament brackets)
  SELECT subscription_tier INTO v_tier
  FROM public.users
  WHERE id = NEW.organizer_id;

  v_max_per_minute := CASE 
    WHEN v_tier = 'pro' THEN 64 
    ELSE 15 
  END;

  SELECT count(*) INTO v_recent_count
  FROM public.matches
  WHERE organizer_id = NEW.organizer_id
    AND created_at > now() - interval '60 seconds';

  IF v_recent_count >= v_max_per_minute THEN
    RAISE EXCEPTION 'RATE_LIMIT_EXCEEDED: Maximum of % matches per minute allowed for your tier.', v_max_per_minute
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_match_creation_rate_guard ON public.matches;
CREATE TRIGGER trg_match_creation_rate_guard
BEFORE INSERT ON public.matches
FOR EACH ROW EXECUTE FUNCTION public.check_match_creation_rate();
