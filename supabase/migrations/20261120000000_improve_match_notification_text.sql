-- ============================================================================
-- Improve match notification title/body specificity and score extraction
-- ============================================================================
-- Fixes:
-- 1. Football/Basketball store scores under scores->'current'->'home'/'away'
--    (not top-level team1/team2), which previously left notification body=''
--    and caused subsequent goals to look identical in the webhook payload.
-- 2. Detects which team scored by comparing OLD.scores vs NEW.scores so
--    notifications say e.g. "Goal for Lech Poznan!" / "SL Benfica 3 - 1 Lech Poznan".
-- 3. Preserves private tournament visibility isolation from 20261102190000.

CREATE OR REPLACE FUNCTION public.handle_match_score_update_notification()
RETURNS TRIGGER AS $$
DECLARE
    r_follower RECORD;
    v_title TEXT;
    v_body TEXT := '';
    v_data JSONB;
    v_team1_name TEXT := 'Team 1';
    v_team2_name TEXT := 'Team 2';
    v_sets JSONB;
    v_set JSONB;
    v_set_str TEXT := '';
    v_s1 TEXT;
    v_s2 TEXT;
    v_new_s1 INT;
    v_new_s2 INT;
    v_old_s1 INT;
    v_old_s2 INT;
    v_existing_id UUID;
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

    -- Extract set-based scores (sets or set_scores)
    IF NEW.scores ? 'sets' AND jsonb_typeof(NEW.scores->'sets') = 'array' THEN
        v_sets := NEW.scores->'sets';
    ELSIF NEW.scores ? 'set_scores' AND jsonb_typeof(NEW.scores->'set_scores') = 'array' THEN
        v_sets := NEW.scores->'set_scores';
    END IF;

    IF v_sets IS NOT NULL THEN
        FOR v_set IN SELECT * FROM jsonb_array_elements(v_sets)
        LOOP
            v_s1 := COALESCE(v_set->>'team1', v_set->>'home', '0');
            v_s2 := COALESCE(v_set->>'team2', v_set->>'away', '0');
            IF v_set_str <> '' THEN
                v_set_str := v_set_str || ', ';
            END IF;
            v_set_str := v_set_str || v_s1 || '-' || v_s2;
        END LOOP;
        IF v_set_str <> '' THEN
            v_body := v_team1_name || ' vs ' || v_team2_name || ' · Score: ' || v_set_str;
        END IF;
    ELSE
        -- Extract current points/goals score from scores.current.home/away or top-level keys
        v_new_s1 := NULLIF(COALESCE(
            NEW.scores->'current'->>'home',
            NEW.scores->>'home',
            NEW.scores->>'team1'
        ), '')::INT;
        v_new_s2 := NULLIF(COALESCE(
            NEW.scores->'current'->>'away',
            NEW.scores->>'away',
            NEW.scores->>'team2'
        ), '')::INT;

        IF TG_OP = 'UPDATE' AND OLD.scores IS NOT NULL THEN
            v_old_s1 := NULLIF(COALESCE(
                OLD.scores->'current'->>'home',
                OLD.scores->>'home',
                OLD.scores->>'team1'
            ), '')::INT;
            v_old_s2 := NULLIF(COALESCE(
                OLD.scores->'current'->>'away',
                OLD.scores->>'away',
                OLD.scores->>'team2'
            ), '')::INT;
        END IF;

        IF v_new_s1 IS NOT NULL AND v_new_s2 IS NOT NULL THEN
            v_body := v_team1_name || ' ' || v_new_s1 || ' - ' || v_new_s2 || ' ' || v_team2_name;
        END IF;
    END IF;

    -- Build specific notification title
    IF NEW.status = 'completed' THEN
        v_title := 'Match Ended: ' || v_team1_name || ' vs ' || v_team2_name;
    ELSIF v_new_s1 IS NOT NULL AND v_new_s2 IS NOT NULL AND v_old_s1 IS NOT NULL AND v_old_s2 IS NOT NULL THEN
        IF v_new_s1 > v_old_s1 AND v_new_s2 = v_old_s2 THEN
            v_title := CASE WHEN NEW.sport_type = 'football' THEN 'Goal for ' ELSE 'Score for ' END || v_team1_name || '!';
        ELSIF v_new_s2 > v_old_s2 AND v_new_s1 = v_old_s1 THEN
            v_title := CASE WHEN NEW.sport_type = 'football' THEN 'Goal for ' ELSE 'Score for ' END || v_team2_name || '!';
        ELSE
            v_title := 'Score Update: ' || v_team1_name || ' vs ' || v_team2_name;
        END IF;
    ELSE
        v_title := 'Score Update: ' || v_team1_name || ' vs ' || v_team2_name;
    END IF;

    v_data := jsonb_build_object(
        'match_id', NEW.id,
        'tournament_id', NEW.tournament_id,
        'type', CASE WHEN NEW.status = 'completed' THEN 'match_completed' ELSE 'score_update' END,
        'link', '/match/' || NEW.id,
        'status', NEW.status,
        'sport_type', NEW.sport_type,
        'scores', NEW.scores
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
