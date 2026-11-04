-- ============================================================================
-- Migration: Declarative Partitioning of match_events with pg_partman
-- File: supabase/migrations/20261104150100_partition_match_events.sql
-- Description:
--   1. Converts public.match_events into a range-partitioned table by created_at.
--   2. Preserves existing data from legacy table into partitioned storage.
--   3. Configures composite timeline index, default safety partition, and RLS policies.
--   4. Sets up pg_partman & pg_cron for automated monthly partition maintenance.
-- ============================================================================

-- 1. Enable extensions for automated partition management if supported by environment
CREATE SCHEMA IF NOT EXISTS partman;

DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_partman WITH SCHEMA partman;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_partman extension could not be installed (likely managed environment without extension privileges). Manual or fallback partition management will apply.';
  END;

  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron extension could not be installed in current schema/environment.';
  END;
END $$;

-- 2. Rename existing match_events table if migrating in-place
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'match_events'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_partitioned_table pt
    JOIN pg_class c ON c.oid = pt.partrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'match_events'
  ) THEN
    ALTER TABLE public.match_events RENAME TO match_events_legacy;
  END IF;
END $$;

-- 3. Create the partitioned match_events table
CREATE TABLE IF NOT EXISTS public.match_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  idempotency_key uuid,
  event_data jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT match_events_pkey PRIMARY KEY (id, created_at),
  CONSTRAINT match_events_idempotency_unique UNIQUE (idempotency_key, created_at)
) PARTITION BY RANGE (created_at);

-- 4. Create default partition as safety net for legacy data or dates outside pre-made ranges
CREATE TABLE IF NOT EXISTS public.match_events_default 
PARTITION OF public.match_events DEFAULT;

-- 5. High-velocity composite index for fetching latest events & Undo stack per match
CREATE INDEX IF NOT EXISTS idx_match_events_match_timeline 
ON public.match_events (match_id, created_at DESC);

-- 6. Configure pg_partman to manage monthly partitions (4 months ahead)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_parent' AND pronamespace = 'partman'::regnamespace) THEN
    PERFORM partman.create_parent(
      p_parent_table := 'public.match_events',
      p_control := 'created_at',
      p_interval := '1 month',
      p_premake := 4
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'partman.create_parent skipped: %', SQLERRM;
END $$;

-- 7. Copy legacy data if legacy table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' AND tablename = 'match_events_legacy'
  ) THEN
    INSERT INTO public.match_events (id, match_id, idempotency_key, event_data, created_at)
    SELECT 
      id, 
      match_id, 
      idempotency_key, 
      event_data, 
      created_at
    FROM public.match_events_legacy
    ON CONFLICT DO NOTHING;

    -- Drop or retain legacy table
    DROP TABLE public.match_events_legacy CASCADE;
  END IF;
END $$;

-- 8. Enable Row Level Security and reapply policies on partitioned table
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Match events visibility policy" ON public.match_events;
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

-- 9. Schedule nightly maintenance via pg_cron if available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
     AND EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'run_maintenance_proc' AND pronamespace = 'partman'::regnamespace) THEN
    PERFORM cron.schedule(
      'maintain-match-events-partitions',
      '0 3 * * *',
      $$ CALL partman.run_maintenance_proc(); $$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'cron.schedule skipped: %', SQLERRM;
END $$;
