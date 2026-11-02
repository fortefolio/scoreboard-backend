-- Migration: 20261102190000_phase3_privacy_and_isolation.sql
-- Purpose:
--   Implements Phase 3 Security Remediation:
--   1. Fix notifications-trigger-private-tournament-score-leak (Phase 3, Medium)
--   2. Fix users-rpc-search-umpires-email-wildcard-oracle (Phase 3, Medium)
--   3. Restrict public.follows insertion on private tournaments

BEGIN;

-- ============================================================================
-- 1. Restrict public.follows Insertion on Private Tournaments
-- ============================================================================

DROP POLICY IF EXISTS "Users can manage their own follows" ON public.follows;
DROP POLICY IF EXISTS "Users can view their own follows" ON public.follows;
DROP POLICY IF EXISTS "Users can insert their own follows" ON public.follows;
DROP POLICY IF EXISTS "Users can delete their own follows" ON public.follows;

CREATE POLICY "Users can view their own follows"
ON public.follows FOR SELECT
USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can insert their own follows"
ON public.follows FOR INSERT
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND (
    entity_type NOT IN ('tournament', 'competition')
    OR EXISTS (
      SELECT 1 FROM public.tournaments t
      WHERE t.id = entity_id
      AND (t.visibility IN ('public', 'unlisted') OR t.organizer_id = (SELECT auth.uid()))
    )
  )
);

CREATE POLICY "Users can delete their own follows"
ON public.follows FOR DELETE
USING (user_id = (SELECT auth.uid()));

-- ============================================================================
-- 2. Enforce Private Tournament Visibility in Match Notification Trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_match_score_update_notification()
RETURNS TRIGGER AS $$
DECLARE
    r_follower RECORD;
    v_title TEXT;
    v_body TEXT;
    v_data JSONB;
    v_team1_name TEXT := 'Team 1';
    v_team2_name TEXT := 'Team 2';
    v_set JSONB;
    v_set_str TEXT := '';
    v_s1 TEXT;
    v_s2 TEXT;
    v_existing_id UUID;
    v_tournament_visibility TEXT;
    v_tournament_organizer UUID;
BEGIN
    -- Only trigger on relevant status or score updates
    IF TG_OP = 'UPDATE' THEN
        IF NEW.scores IS NOT DISTINCT FROM OLD.scores AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
            RETURN NEW;
        END IF;
    END IF;

    -- Extract participant names if available
    IF NEW.participants IS NOT NULL AND jsonb_array_length(NEW.participants) >= 2 THEN
        v_team1_name := COALESCE(NEW.participants->0->>'name', 'Team 1');
        v_team2_name := COALESCE(NEW.participants->1->>'name', 'Team 2');
    END IF;

    -- Build notification message
    IF NEW.status = 'completed' THEN
        v_title := 'Match Ended: ' || v_team1_name || ' vs ' || v_team2_name;
    ELSE
        v_title := 'Score Update: ' || v_team1_name || ' vs ' || v_team2_name;
    END IF;

    v_body := '';
    IF NEW.scores ? 'sets' AND jsonb_typeof(NEW.scores->'sets') = 'array' THEN
        FOR v_set IN SELECT * FROM jsonb_array_elements(NEW.scores->'sets')
        LOOP
            v_s1 := COALESCE(v_set->>'team1', v_set->>'home', '0');
            v_s2 := COALESCE(v_set->>'team2', v_set->>'away', '0');
            IF v_set_str <> '' THEN
                v_set_str := v_set_str || ', ';
            END IF;
            v_set_str := v_set_str || v_s1 || '-' || v_s2;
        END LOOP;
        IF v_set_str <> '' THEN
            v_body := v_body || 'Score: ' || v_set_str;
        END IF;
    ELSIF NEW.scores ? 'team1' AND NEW.scores ? 'team2' THEN
        v_body := v_body || (NEW.scores->>'team1') || ' - ' || (NEW.scores->>'team2');
    END IF;

    v_data := jsonb_build_object(
        'match_id', NEW.id,
        'tournament_id', NEW.tournament_id,
        'type', CASE WHEN NEW.status = 'completed' THEN 'match_completed' ELSE 'score_update' END,
        'link', '/match/' || NEW.id,
        'status', NEW.status,
        'sport_type', NEW.sport_type
    );

    -- Iterate over followers while strictly enforcing private tournament data isolation
    FOR r_follower IN
        SELECT DISTINCT f.user_id
        FROM public.follows f
        LEFT JOIN public.tournaments t ON t.id = NEW.tournament_id
        WHERE 
            (
                (f.entity_type = 'match' AND f.entity_id = NEW.id)
                OR
                (NEW.tournament_id IS NOT NULL AND f.entity_type IN ('tournament', 'competition') AND f.entity_id = NEW.tournament_id)
                OR
                (f.entity_type IN ('team', 'player') AND NEW.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
            )
            AND (
                NEW.tournament_id IS NULL
                OR t.visibility IN ('public', 'unlisted')
                OR t.organizer_id = f.user_id
            )
    LOOP
        -- Check if user already has an existing notification for this match
        SELECT id INTO v_existing_id
        FROM public.notifications
        WHERE user_id = r_follower.user_id
          AND ((data->>'match_id') = NEW.id::text OR (data->>'matchId') = NEW.id::text)
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            UPDATE public.notifications
            SET title = v_title,
                body = v_body,
                data = v_data,
                read_at = NULL,
                created_at = pg_catalog.now()
            WHERE id = v_existing_id;
        ELSE
            INSERT INTO public.notifications (user_id, title, body, data, created_at)
            VALUES (r_follower.user_id, v_title, v_body, v_data, pg_catalog.now());
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ============================================================================
-- 3. Harden search_umpires RPC against SQL Wildcard Probing
-- ============================================================================

CREATE OR REPLACE FUNCTION public.search_umpires(p_query TEXT)
RETURNS TABLE (
  id UUID, 
  username TEXT
) AS $$
DECLARE
  v_escaped TEXT;
BEGIN
  -- Require at least 3 characters to search
  IF length(trim(coalesce(p_query, ''))) < 3 THEN
    RETURN;
  END IF;

  -- Escape LIKE wildcards to prevent blind oracle probing
  v_escaped := replace(replace(replace(trim(p_query), '\', '\\'), '%', '\%'), '_', '\_');

  RETURN QUERY
  SELECT u.id, u.username
  FROM public.users u
  WHERE u.username ILIKE '%' || v_escaped || '%'
     OR u.email ILIKE v_escaped || '%'
  LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.search_umpires(TEXT) TO authenticated;

COMMIT;
