-- Migration: 20260522070000_follow_system_and_aggregated_notifications.sql
-- Description: Add match & tournament support to follows and implement aggregated score notifications for followers

-- Ensure entity_type has 'match' and 'tournament'
ALTER TYPE entity_type ADD VALUE IF NOT EXISTS 'match';
ALTER TYPE entity_type ADD VALUE IF NOT EXISTS 'tournament';

-- Function to handle score updates and aggregate notifications per match
CREATE OR REPLACE FUNCTION public.handle_match_score_update_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    r_follower RECORD;
    v_existing_id UUID;
    v_title TEXT;
    v_body TEXT := '';
    v_data JSONB;
    v_p1 TEXT;
    v_p2 TEXT;
    v_set_str TEXT := '';
    v_set JSONB;
    v_s1 TEXT;
    v_s2 TEXT;
BEGIN
    -- Only trigger if score or status actually changed
    IF (TG_OP = 'UPDATE') AND (
        (NEW.scores IS DISTINCT FROM OLD.scores) OR 
        (NEW.status IS DISTINCT FROM OLD.status)
    ) THEN
        -- Build Match Title from participants if available
        v_p1 := COALESCE(NEW.participants->0->>'name', 'Team 1');
        v_p2 := COALESCE(NEW.participants->1->>'name', 'Team 2');
        v_title := v_p1 || ' vs ' || v_p2;

        -- Format body with score summary or status
        IF NEW.status::text = 'completed' THEN
            v_body := 'Match completed. ';
        ELSIF NEW.status::text = 'ongoing' THEN
            v_body := 'Live update: ';
        ELSE
            v_body := 'Status: ' || NEW.status::text || '. ';
        END IF;

        -- Format sets if present in scores
        IF NEW.scores ? 'sets' AND jsonb_typeof(NEW.scores->'sets') = 'array' AND jsonb_array_length(NEW.scores->'sets') > 0 THEN
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

        -- Iterate over all distinct users following this match or the tournament or participants
        FOR r_follower IN
            SELECT DISTINCT f.user_id
            FROM public.follows f
            WHERE 
                -- Following this specific match
                (f.entity_type = 'match' AND f.entity_id = NEW.id)
                OR
                -- Following the tournament
                (NEW.tournament_id IS NOT NULL AND f.entity_type IN ('tournament', 'competition') AND f.entity_id = NEW.tournament_id)
                OR
                -- Following a participant
                (f.entity_type IN ('team', 'player') AND NEW.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
        LOOP
            -- Check if user already has an existing notification for this match
            SELECT id INTO v_existing_id
            FROM public.notifications
            WHERE user_id = r_follower.user_id
              AND ((data->>'match_id') = NEW.id::text OR (data->>'matchId') = NEW.id::text)
            ORDER BY created_at DESC
            LIMIT 1;

            IF v_existing_id IS NOT NULL THEN
                -- Aggregate into existing notification: update content, unread state, and bump timestamp to top
                UPDATE public.notifications
                SET title = v_title,
                    body = v_body,
                    data = v_data,
                    read_at = NULL,
                    created_at = NOW()
                WHERE id = v_existing_id;
            ELSE
                -- Insert fresh notification
                INSERT INTO public.notifications (user_id, title, body, data, created_at)
                VALUES (r_follower.user_id, v_title, v_body, v_data, NOW());
            END IF;
        END LOOP;

    END IF;

    RETURN NEW;
END;
$$;

-- Drop legacy completion trigger and replace with score update aggregator
DROP TRIGGER IF EXISTS tr_notify_match_completion ON public.matches;

DROP TRIGGER IF EXISTS tr_notify_match_score_update ON public.matches;
CREATE TRIGGER tr_notify_match_score_update
AFTER UPDATE ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_match_score_update_notification();
