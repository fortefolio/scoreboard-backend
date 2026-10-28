-- Migration: Security, Auth, Registration & Scoring Engine Fixes
-- Consolidates PII protection, column/path alignment, RPC authorization, and sport scoring fixes.

BEGIN;

-- ============================================================================
-- 1. Resilient User Creation Trigger (Prevent username collision failures)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    v_base_username TEXT;
    v_final_username TEXT;
BEGIN
    v_base_username := COALESCE(
        NULLIF(trim(new.raw_user_meta_data->>'display_name'), ''),
        NULLIF(trim(new.raw_user_meta_data->>'username'), ''),
        NULLIF(trim(new.raw_user_meta_data->>'full_name'), ''),
        NULLIF(trim(new.raw_user_meta_data->>'name'), ''),
        NULLIF(trim(new.raw_user_meta_data->>'user_name'), ''),
        split_part(new.email, '@', 1)
    );

    v_final_username := v_base_username;

    IF EXISTS (SELECT 1 FROM public.users WHERE lower(username) = lower(v_final_username)) THEN
        v_final_username := v_base_username || '_' || substr(new.id::text, 1, 6);
    END IF;

    BEGIN
        INSERT INTO public.users (id, subscription_tier, email, username)
        VALUES (
            new.id,
            'free',
            new.email,
            v_final_username
        );
    EXCEPTION WHEN unique_violation THEN
        INSERT INTO public.users (id, subscription_tier, email, username)
        VALUES (
            new.id,
            'free',
            new.email,
            v_base_username || '_' || substr(new.id::text, 1, 8)
        );
    END;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================================
-- 2. Protect PII on public.users & Allow Profile Updates
-- ============================================================================
-- Restrict anon to only reading (id, username) for uniqueness checks during signup.
-- Authenticated users retain read access for umpire search.
REVOKE SELECT ON public.users FROM anon;
GRANT SELECT (id, username) ON public.users TO anon;

-- Prevent authenticated users from directly updating subscription_tier or email
REVOKE INSERT, UPDATE, DELETE ON public.users FROM authenticated;
GRANT UPDATE (username, updated_at) ON public.users TO authenticated;

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile"
ON public.users FOR UPDATE
USING (id = (SELECT auth.uid()))
WITH CHECK (id = (SELECT auth.uid()));


-- ============================================================================
-- 3. Protect PII & Fix RLS/Triggers on public.tournament_participants
-- ============================================================================
-- Restrict direct table SELECT to non-PII columns for both anon and authenticated.
REVOKE SELECT ON public.tournament_participants FROM anon, authenticated;
GRANT SELECT (id, tournament_id, name, seed, created_at) ON public.tournament_participants TO anon, authenticated;

-- Secure RPC for Tournament Organizers to fetch full participant details (including PII)
CREATE OR REPLACE FUNCTION public.get_tournament_participants_admin(p_tournament_id UUID)
RETURNS TABLE (
    id UUID,
    tournament_id UUID,
    name TEXT,
    contact_email TEXT,
    form_responses JSONB,
    seed INT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = p_tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    ) THEN
        RAISE EXCEPTION 'Not authorized to view participant details for this tournament';
    END IF;

    RETURN QUERY
    SELECT
        tp.id,
        tp.tournament_id,
        tp.name,
        tp.contact_email,
        tp.form_responses,
        tp.seed,
        tp.created_at
    FROM public.tournament_participants tp
    WHERE tp.tournament_id = p_tournament_id
    ORDER BY tp.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_tournament_participants_admin(UUID) TO authenticated;

-- Consolidate & harden RLS policies on public.tournament_participants
DROP POLICY IF EXISTS "Allow public read of participants" ON public.tournament_participants;
DROP POLICY IF EXISTS "Allow public signups" ON public.tournament_participants;
DROP POLICY IF EXISTS "Participants visibility policy" ON public.tournament_participants;
DROP POLICY IF EXISTS "Organizers can update participants" ON public.tournament_participants;
DROP POLICY IF EXISTS "Organizers can delete participants" ON public.tournament_participants;

CREATE POLICY "Participants visibility policy"
ON public.tournament_participants FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND (t.visibility = 'public' OR t.visibility = 'unlisted' OR t.organizer_id = (SELECT auth.uid()))
    )
);

CREATE POLICY "Allow public signups"
ON public.tournament_participants FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.status = 'pending'
    )
);

CREATE POLICY "Organizers can update participants"
ON public.tournament_participants FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    )
);

CREATE POLICY "Organizers can delete participants"
ON public.tournament_participants FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
        AND t.organizer_id = (SELECT auth.uid())
    )
);

-- Fix max_teams JSON path check and prevent duplicate team names in check_tournament_participant_limit()
CREATE OR REPLACE FUNCTION public.check_tournament_participant_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_max_teams INT;
    v_current_teams INT;
BEGIN
    -- Lock tournament row to serialize concurrent signups
    SELECT COALESCE(
        (settings->>'max_teams')::int,
        (settings->'stage_1'->>'max_teams')::int
    )
    INTO v_max_teams
    FROM public.tournaments
    WHERE id = NEW.tournament_id
    FOR UPDATE;

    -- Prevent duplicate team/player names in the same tournament (case-insensitive)
    IF EXISTS (
        SELECT 1
        FROM public.tournament_participants
        WHERE tournament_id = NEW.tournament_id
          AND lower(trim(name)) = lower(trim(NEW.name))
    ) THEN
        RAISE EXCEPTION 'A team or player named "%" is already registered for this tournament', trim(NEW.name);
    END IF;

    IF v_max_teams IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*)
    INTO v_current_teams
    FROM public.tournament_participants
    WHERE tournament_id = NEW.tournament_id;

    IF v_current_teams >= v_max_teams THEN
        RAISE EXCEPTION 'This tournament has reached the maximum number of participants (%)', v_max_teams;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Replace hardcoded placeholder URL in handle_new_signup() with configurable GUC settings
CREATE OR REPLACE FUNCTION public.handle_new_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_supabase_url TEXT;
    v_service_key TEXT;
BEGIN
    v_supabase_url := NULLIF(current_setting('app.settings.supabase_url', true), '');
    v_service_key := NULLIF(current_setting('app.settings.service_role_key', true), '');

    -- Only invoke pg_net if valid project settings are configured
    IF v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL AND v_supabase_url NOT LIKE '%your-project.supabase.co%' THEN
        PERFORM net.http_post(
            url := rtrim(v_supabase_url, '/') || '/functions/v1/send-signup-email',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || v_service_key
            ),
            body := jsonb_build_object('record', row_to_json(NEW))
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Enhance dynamic signup form validation (checkbox boolean, number min/max, select options)
CREATE OR REPLACE FUNCTION public.validate_participant_form_responses()
RETURNS TRIGGER AS $$
DECLARE
    v_config JSONB;
    v_field JSONB;
    v_field_id TEXT;
    v_field_type TEXT;
    v_field_label TEXT;
    v_required BOOLEAN;
    v_raw_val TEXT;
    v_num_val NUMERIC;
BEGIN
    SELECT signup_schema INTO v_config
    FROM public.tournaments
    WHERE id = NEW.tournament_id;

    IF v_config IS NULL OR jsonb_array_length(v_config) = 0 THEN
        RETURN NEW;
    END IF;

    FOR v_field IN SELECT * FROM jsonb_array_elements(v_config)
    LOOP
        v_field_id := v_field->>'id';
        v_field_type := COALESCE(v_field->>'type', 'text');
        v_field_label := COALESCE(NULLIF(v_field->>'label', ''), v_field_id);
        v_required := COALESCE((v_field->>'required')::BOOLEAN, FALSE);
        v_raw_val := CASE WHEN NEW.form_responses IS NOT NULL THEN NEW.form_responses->>v_field_id ELSE NULL END;

        IF v_required THEN
            IF v_field_type = 'checkbox' THEN
                IF v_raw_val IS DISTINCT FROM 'true' THEN
                    RAISE EXCEPTION 'Missing required agreement: %', v_field_label;
                END IF;
            ELSIF v_raw_val IS NULL OR trim(v_raw_val) = '' THEN
                RAISE EXCEPTION 'Missing required field: %', v_field_label;
            END IF;
        END IF;

        IF v_raw_val IS NOT NULL AND trim(v_raw_val) <> '' THEN
            IF v_field_type = 'number' THEN
                BEGIN
                    v_num_val := v_raw_val::NUMERIC;
                EXCEPTION WHEN OTHERS THEN
                    RAISE EXCEPTION 'Field "%" must be a valid number', v_field_label;
                END;

                IF (v_field->>'min') IS NOT NULL AND v_num_val < (v_field->>'min')::NUMERIC THEN
                    RAISE EXCEPTION 'Field "%" must be at least %', v_field_label, (v_field->>'min');
                END IF;
                IF (v_field->>'max') IS NOT NULL AND v_num_val > (v_field->>'max')::NUMERIC THEN
                    RAISE EXCEPTION 'Field "%" must be at most %', v_field_label, (v_field->>'max');
                END IF;
            ELSIF v_field_type = 'select' AND jsonb_typeof(v_field->'options') = 'array' AND jsonb_array_length(v_field->'options') > 0 THEN
                IF NOT (v_field->'options' ? v_raw_val) THEN
                    RAISE EXCEPTION 'Invalid option selected for field "%"', v_field_label;
                END IF;
            END IF;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;


-- ============================================================================
-- 4. Lock Down SECURITY DEFINER RPCs with Explicit Authorization Checks
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
        AND (umpire_id = (SELECT auth.uid()) OR organizer_id = (SELECT auth.uid()))
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
        updated_at = NOW()
    WHERE id = m_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.update_tennis_score(m_id UUID, winner_idx INT)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = m_id
        AND (umpire_id = (SELECT auth.uid()) OR organizer_id = (SELECT auth.uid()))
    ) THEN
        RAISE EXCEPTION 'Not authorized to update score for this match';
    END IF;

    INSERT INTO public.match_events (match_id, event_data)
    VALUES (
        m_id,
        jsonb_build_object(
            'type', 'point_won',
            'side', CASE WHEN winner_idx = 0 THEN 'home' ELSE 'away' END
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.accept_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = p_match_id AND umpire_id = (SELECT auth.uid())
    ) THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    UPDATE public.matches
    SET umpire_invite_status = 'accepted'
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.refuse_umpire_invitation(p_match_id UUID, p_notification_id UUID)
RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.matches
        WHERE id = p_match_id AND umpire_id = (SELECT auth.uid())
    ) THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    UPDATE public.matches
    SET umpire_invite_status = 'refused',
        umpire_id = NULL
    WHERE id = p_match_id AND umpire_id = (SELECT auth.uid());

    UPDATE public.notifications
    SET read_at = NOW()
    WHERE id = p_notification_id AND user_id = (SELECT auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================================
-- 5. Update Volleyball & Football Scoring in Dispatcher Trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_volleyball_score(
    p_scores JSONB,
    v_side TEXT,
    v_rules JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_max_sets INT := COALESCE((v_rules->>'max_sets')::INT, 3);
    v_sets_to_win INT := CEIL(COALESCE((v_rules->>'max_sets')::NUMERIC, 3) / 2.0)::INT;
    v_sets JSONB := COALESCE(p_scores->'sets', p_scores->'set_scores', '[]'::jsonb);
    v_current_set INT := COALESCE((p_scores->>'current_set')::INT, jsonb_array_length(v_sets) + 1);
    v_is_deciding_set BOOLEAN := (jsonb_array_length(v_sets) = (v_max_sets - 1));
    v_target_points INT := CASE
        WHEN v_is_deciding_set THEN COALESCE((v_rules->>'deciding_set_points')::INT, 15)
        ELSE COALESCE((v_rules->>'points_per_set')::INT, 25)
    END;
    v_point_cap INT := (v_rules->>'point_cap')::INT;
    v_p1_current INT := COALESCE((p_scores->'current'->>'home')::INT, 0);
    v_p2_current INT := COALESCE((p_scores->'current'->>'away')::INT, 0);
    v_set_won BOOLEAN := FALSE;
    v_match_won BOOLEAN := FALSE;
    v_serving_idx INT := CASE WHEN v_side = 'home' THEN 0 ELSE 1 END;
    v_sets_p1 INT := 0;
    v_sets_p2 INT := 0;
    v_s JSONB;
BEGIN
    IF v_side = 'home' THEN
        v_p1_current := v_p1_current + 1;
    ELSE
        v_p2_current := v_p2_current + 1;
    END IF;

    IF (v_point_cap IS NOT NULL AND (v_p1_current >= v_point_cap OR v_p2_current >= v_point_cap)) THEN
        v_set_won := TRUE;
    ELSIF (v_p1_current >= v_target_points OR v_p2_current >= v_target_points) AND ABS(v_p1_current - v_p2_current) >= 2 THEN
        v_set_won := TRUE;
    END IF;

    IF v_set_won THEN
        v_sets := v_sets || jsonb_build_object('team1', v_p1_current, 'team2', v_p2_current, 'home', v_p1_current, 'away', v_p2_current);
        FOR v_s IN SELECT * FROM jsonb_array_elements(v_sets) LOOP
            IF COALESCE((v_s->>'team1')::INT, (v_s->>'home')::INT, 0) > COALESCE((v_s->>'team2')::INT, (v_s->>'away')::INT, 0) THEN
                v_sets_p1 := v_sets_p1 + 1;
            ELSE
                v_sets_p2 := v_sets_p2 + 1;
            END IF;
        END LOOP;

        IF v_sets_p1 >= v_sets_to_win OR v_sets_p2 >= v_sets_to_win THEN
            v_match_won := TRUE;
        END IF;

        RETURN jsonb_build_object(
            'current', '{"home": 0, "away": 0}'::jsonb,
            'sets', v_sets,
            'set_scores', v_sets,
            'current_set', v_current_set + 1,
            'serving_index', v_serving_idx,
            'match_won', v_match_won
        );
    ELSE
        RETURN jsonb_build_object(
            'current', jsonb_build_object('home', v_p1_current, 'away', v_p2_current),
            'sets', v_sets,
            'set_scores', v_sets,
            'current_set', v_current_set,
            'serving_index', v_serving_idx,
            'match_won', FALSE
        );
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match record;
    v_rules JSONB;
    v_scores JSONB;
    v_result JSONB;
    v_side TEXT;
    v_match_won BOOLEAN := FALSE;
    v_football JSONB;
BEGIN
    SELECT m.*, t.settings as tournament_settings
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    v_scores := COALESCE(v_match.scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb);
    v_rules := COALESCE(v_match.settings, v_match.tournament_settings->'default', '{}'::jsonb);

    -- Handle Meta-Events
    IF NEW.event_data->>'type' = 'start_scoreboard' THEN
        IF (NEW.event_data ? 'initial_server_index') AND NEW.event_data->>'initial_server_index' IS NOT NULL THEN
            v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->>'initial_server_index')::jsonb);
        END IF;
        UPDATE public.matches SET status = 'ongoing', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    IF NEW.event_data->>'type' = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->>'winner_index')::jsonb);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    IF NEW.event_data->>'type' IN ('clock_toggle', 'period_change') THEN
        v_football := COALESCE(v_scores->'football', '{"period": "1st Half", "elapsed_seconds": 0, "is_clock_running": false}'::jsonb);
        IF NEW.event_data ? 'period' THEN
            v_football := jsonb_set(v_football, '{period}', to_jsonb(NEW.event_data->>'period'));
        END IF;
        IF NEW.event_data ? 'is_running' THEN
            v_football := jsonb_set(v_football, '{is_clock_running}', (NEW.event_data->'is_running'));
        END IF;
        IF NEW.event_data ? 'elapsed_seconds' THEN
            v_football := jsonb_set(v_football, '{elapsed_seconds}', (NEW.event_data->'elapsed_seconds'));
        END IF;
        v_scores := jsonb_set(v_scores, '{football}', v_football);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- Dispatch to specialist based on sport
    IF NEW.event_data->>'type' IN ('point_won', 'score', 'goal', 'point_scored') THEN
        v_side := NEW.event_data->>'side';
        IF v_side IS NULL THEN RETURN NEW; END IF;

        CASE lower(COALESCE(v_match.sport_type, 'generic'))
            WHEN 'tennis' THEN
                IF NOT (v_scores ? 'tennis') THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 1, "is_tiebreak": false}'::jsonb);
                END IF;
                v_result := public.calculate_tennis_score(v_scores, (CASE WHEN v_side = 'home' THEN 0 ELSE 1 END), v_rules);
                v_match_won := COALESCE((v_result->>'match_won')::BOOLEAN, FALSE);
                v_scores := v_scores || v_result;

            WHEN 'volleyball', 'beach_volleyball' THEN
                v_result := public.calculate_volleyball_score(v_scores, v_side, v_rules);
                v_match_won := COALESCE((v_result->>'match_won')::BOOLEAN, FALSE);
                v_scores := v_scores || v_result;

            WHEN 'basketball' THEN
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side],
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + COALESCE((NEW.event_data->>'points')::INT, 1))::TEXT)::jsonb);

            ELSE
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side],
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    IF v_match_won THEN
        UPDATE public.matches SET status = 'completed', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    ELSE
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================================
-- 6. Fix Notification Route Link in handle_match_completion_notification()
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_match_completion_notification()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status <> 'completed') THEN
        INSERT INTO public.notifications (user_id, title, body, data)
        SELECT
            f.user_id,
            'Match Completed!',
            NEW.sport_type || ' match finished.',
            jsonb_build_object(
                'match_id', NEW.id,
                'tournament_id', NEW.tournament_id,
                'type', 'match_completed',
                'link', '/match/' || NEW.id,
                'final_sets', NEW.scores->'final_sets'
            )
        FROM public.follows f
        WHERE
            (f.entity_type IN ('team', 'player') AND NEW.participants @> jsonb_build_array(jsonb_build_object('id', f.entity_id)))
            OR
            (f.entity_type = 'competition' AND NEW.tournament_id = f.entity_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMIT;
