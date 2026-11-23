-- 2. Update handle_match_score_update_notification() with event classification & user preference filtering
CREATE OR REPLACE FUNCTION public.handle_match_score_update_notification()
RETURNS TRIGGER AS $$
DECLARE
    r_follower RECORD;
    v_title TEXT;
    v_body TEXT := '';
    v_data JSONB;
    v_team1_name TEXT := 'Team 1';
    v_team2_name TEXT := 'Team 2';
    v_sport TEXT := LOWER(COALESCE(NEW.sport_type, 'generic'));
    v_sets JSONB;
    v_old_sets JSONB;
    v_set JSONB;
    v_set_str TEXT := '';
    v_s1 TEXT;
    v_s2 TEXT;
    v_new_s1 INT;
    v_new_s2 INT;
    v_old_s1 INT;
    v_old_s2 INT;
    v_existing_id UUID;

    -- Event classification flags
    v_is_match_started BOOLEAN := FALSE;
    v_is_match_ended BOOLEAN := FALSE;
    v_sets_changed BOOLEAN := FALSE;
    v_games_or_points_changed BOOLEAN := FALSE;
    v_cards_changed BOOLEAN := FALSE;
    v_quarter_changed BOOLEAN := FALSE;
    v_is_milestone BOOLEAN := FALSE;
    v_period TEXT;

    -- Per-follower preference checks
    v_prefs JSONB;
    v_all_enabled BOOLEAN;
    v_sport_specific_enabled BOOLEAN;
    v_tennis_sets BOOLEAN;
    v_tennis_games BOOLEAN;
    v_volley_sets BOOLEAN;
    v_volley_points BOOLEAN;
    v_fb_goals BOOLEAN;
    v_fb_cards BOOLEAN;
    v_bb_points BOOLEAN;
    v_bb_quarters BOOLEAN;
    v_should_notify BOOLEAN;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.scores IS NOT DISTINCT FROM OLD.scores AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
            RETURN NEW;
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        v_is_match_ended := (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed');
        v_is_match_started := (NEW.status = 'ongoing' AND OLD.status = 'scheduled');
    END IF;

    -- Extract participant names
    IF NEW.participants IS NOT NULL AND jsonb_array_length(NEW.participants) >= 2 THEN
        v_team1_name := COALESCE(NEW.participants->0->>'name', 'Team 1');
        v_team2_name := COALESCE(NEW.participants->1->>'name', 'Team 2');
    END IF;

    -- Extract non-empty set-based scores (new & old)
    IF NEW.scores->'tennis' ? 'sets' AND jsonb_typeof(NEW.scores->'tennis'->'sets') = 'array' AND jsonb_array_length(NEW.scores->'tennis'->'sets') > 0 THEN
        v_sets := NEW.scores->'tennis'->'sets';
    ELSIF NEW.scores->'padel' ? 'sets' AND jsonb_typeof(NEW.scores->'padel'->'sets') = 'array' AND jsonb_array_length(NEW.scores->'padel'->'sets') > 0 THEN
        v_sets := NEW.scores->'padel'->'sets';
    ELSIF NEW.scores ? 'set_scores' AND jsonb_typeof(NEW.scores->'set_scores') = 'array' AND jsonb_array_length(NEW.scores->'set_scores') > 0 THEN
        v_sets := NEW.scores->'set_scores';
    ELSIF NEW.scores ? 'sets' AND jsonb_typeof(NEW.scores->'sets') = 'array' AND jsonb_array_length(NEW.scores->'sets') > 0 THEN
        v_sets := NEW.scores->'sets';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.scores IS NOT NULL THEN
        IF OLD.scores->'tennis' ? 'sets' AND jsonb_typeof(OLD.scores->'tennis'->'sets') = 'array' THEN
            v_old_sets := OLD.scores->'tennis'->'sets';
        ELSIF OLD.scores->'padel' ? 'sets' AND jsonb_typeof(OLD.scores->'padel'->'sets') = 'array' THEN
            v_old_sets := OLD.scores->'padel'->'sets';
        ELSIF OLD.scores ? 'set_scores' AND jsonb_typeof(OLD.scores->'set_scores') = 'array' THEN
            v_old_sets := OLD.scores->'set_scores';
        ELSIF OLD.scores ? 'sets' AND jsonb_typeof(OLD.scores->'sets') = 'array' THEN
            v_old_sets := OLD.scores->'sets';
        END IF;
    END IF;

    v_sets_changed := (
        (v_sets IS DISTINCT FROM v_old_sets) AND (v_sets IS NOT NULL)
    );

    -- Extract current games/points/goals
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

    v_games_or_points_changed := (
        (v_new_s1 IS DISTINCT FROM v_old_s1) OR (v_new_s2 IS DISTINCT FROM v_old_s2)
    );

    IF v_sport = 'football' AND TG_OP = 'UPDATE' THEN
        v_cards_changed := (
            (NEW.scores->'football'->'yellow_cards' IS DISTINCT FROM OLD.scores->'football'->'yellow_cards')
            OR (NEW.scores->'football'->'red_cards' IS DISTINCT FROM OLD.scores->'football'->'red_cards')
        );
    END IF;

    IF v_sport = 'basketball' AND TG_OP = 'UPDATE' THEN
        v_quarter_changed := (
            (NEW.scores->'basketball'->>'period') IS DISTINCT FROM (OLD.scores->'basketball'->>'period')
        );
    END IF;

    -- Quota guard: For Tennis/Padel, NEVER fire notifications for individual point updates
    IF v_sport IN ('tennis', 'padel')
       AND NOT v_is_match_started
       AND NOT v_is_match_ended
       AND NOT v_sets_changed
       AND NOT v_games_or_points_changed THEN
        RETURN NEW;
    END IF;

    IF v_sets IS NOT NULL THEN
        FOR v_set IN SELECT * FROM jsonb_array_elements(v_sets)
        LOOP
            v_s1 := COALESCE(v_set->>0, v_set->>'team1', v_set->>'home', '0');
            v_s2 := COALESCE(v_set->>1, v_set->>'team2', v_set->>'away', '0');
            IF v_set_str <> '' THEN
                v_set_str := v_set_str || ', ';
            END IF;
            v_set_str := v_set_str || v_s1 || '-' || v_s2;
        END LOOP;
        IF v_new_s1 IS NOT NULL AND v_new_s2 IS NOT NULL THEN
            v_body := v_team1_name || ' vs ' || v_team2_name || ' · Sets: ' || v_set_str || ' (' || v_new_s1 || '-' || v_new_s2 || ')';
        ELSE
            v_body := v_team1_name || ' vs ' || v_team2_name || ' · Score: ' || v_set_str;
        END IF;
    ELSIF v_new_s1 IS NOT NULL AND v_new_s2 IS NOT NULL THEN
        v_body := v_team1_name || ' ' || v_new_s1 || ' - ' || v_new_s2 || ' ' || v_team2_name;
    END IF;

    v_period := NEW.scores->'basketball'->>'period';
    IF v_sport = 'basketball' AND v_period IS NOT NULL AND NOT v_is_match_started AND NOT v_is_match_ended THEN
        v_body := COALESCE(v_body, v_team1_name || ' vs ' || v_team2_name) || ' · ' || v_period;
    ELSIF v_is_match_ended AND v_body <> '' THEN
        v_body := v_body || ' · Final';
    ELSIF v_is_match_started THEN
        v_body := 'Match is now live';
    END IF;

    -- Build specific notification title
    IF v_is_match_ended THEN
        v_title := 'Match Ended: ' || v_team1_name || ' vs ' || v_team2_name;
    ELSIF v_is_match_started THEN
        v_title := 'Match Started: ' || v_team1_name || ' vs ' || v_team2_name;
    ELSIF v_sport = 'basketball' AND v_quarter_changed AND NOT v_games_or_points_changed THEN
        v_title := COALESCE(v_period, 'Period') || ' Started: ' || v_team1_name || ' vs ' || v_team2_name;
    ELSIF v_sport = 'football' AND v_cards_changed AND NOT v_games_or_points_changed THEN
        IF (NEW.scores->'football'->'red_cards' IS DISTINCT FROM OLD.scores->'football'->'red_cards') THEN
            v_title := 'Red Card: ' || v_team1_name || ' vs ' || v_team2_name;
        ELSE
            v_title := 'Yellow Card: ' || v_team1_name || ' vs ' || v_team2_name;
        END IF;
    ELSIF v_new_s1 IS NOT NULL AND v_new_s2 IS NOT NULL AND v_old_s1 IS NOT NULL AND v_old_s2 IS NOT NULL THEN
        IF v_new_s1 > v_old_s1 AND v_new_s2 = v_old_s2 THEN
            v_title := CASE WHEN v_sport = 'football' THEN 'Goal for ' ELSE 'Score for ' END || v_team1_name || '!';
        ELSIF v_new_s2 > v_old_s2 AND v_new_s1 = v_old_s1 THEN
            v_title := CASE WHEN v_sport = 'football' THEN 'Goal for ' ELSE 'Score for ' END || v_team2_name || '!';
        ELSE
            v_title := 'Score Update: ' || v_team1_name || ' vs ' || v_team2_name;
        END IF;
    ELSE
        v_title := 'Score Update: ' || v_team1_name || ' vs ' || v_team2_name;
    END IF;

    -- Milestones create their own row; high-frequency live updates collapse into 1 live row per match
    v_is_milestone := (
        v_is_match_started
        OR v_is_match_ended
        OR (v_sport = 'football' AND (v_games_or_points_changed OR v_cards_changed))
        OR (v_sport IN ('tennis', 'padel', 'volleyball', 'beach_volleyball') AND v_sets_changed)
    );

    v_data := jsonb_build_object(
        'match_id', NEW.id,
        'tournament_id', NEW.tournament_id,
        'type', CASE
            WHEN v_is_match_ended THEN 'match_completed'
            WHEN v_is_match_started THEN 'match_started'
            ELSE 'score_update'
        END,
        'link', '/match/' || NEW.id,
        'status', NEW.status,
        'sport_type', NEW.sport_type,
        'scores', NEW.scores
    );

    IF NOT v_is_milestone THEN
        v_data := v_data || jsonb_build_object('collapse_key', 'match_' || NEW.id || '_live');
    END IF;

    -- Iterate over followers while enforcing private tournament isolation & notification preferences
    FOR r_follower IN
        SELECT DISTINCT f.user_id, u.preferences->'notifications' AS notif_prefs
        FROM public.follows f
        LEFT JOIN public.tournaments t ON t.id = NEW.tournament_id
        LEFT JOIN public.users u ON u.id = f.user_id
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
        v_prefs := COALESCE(r_follower.notif_prefs, '{}'::jsonb);
        v_should_notify := TRUE;
        v_all_enabled := COALESCE((v_prefs->>'enabled')::BOOLEAN, TRUE);
        v_sport_specific_enabled := COALESCE((v_prefs->>'sport_specific_enabled')::BOOLEAN, TRUE);

        IF NOT v_all_enabled THEN
            v_should_notify := FALSE;
        ELSIF v_is_match_ended THEN
            v_should_notify := COALESCE((v_prefs->>'match_ended')::BOOLEAN, TRUE);
        ELSIF v_is_match_started THEN
            v_should_notify := COALESCE((v_prefs->>'match_started')::BOOLEAN, TRUE);
        ELSIF NOT v_sport_specific_enabled THEN
            v_should_notify := FALSE;
        ELSIF v_sport IN ('tennis', 'padel') THEN
            IF NOT COALESCE((v_prefs->>'tennis_padel_enabled')::BOOLEAN, TRUE) THEN
                v_should_notify := FALSE;
            ELSE
                v_tennis_sets := COALESCE((v_prefs->>'tennis_padel_sets')::BOOLEAN, (v_prefs->>'tennis_padel_granularity') IS DISTINCT FROM 'none');
                v_tennis_games := COALESCE((v_prefs->>'tennis_padel_games')::BOOLEAN, (v_prefs->>'tennis_padel_granularity') = 'game');
                v_should_notify := (v_sets_changed AND v_tennis_sets) OR (v_games_or_points_changed AND v_tennis_games);
            END IF;
        ELSIF v_sport IN ('volleyball', 'beach_volleyball') THEN
            IF NOT COALESCE((v_prefs->>'volleyball_enabled')::BOOLEAN, TRUE) THEN
                v_should_notify := FALSE;
            ELSE
                v_volley_sets := COALESCE((v_prefs->>'volleyball_sets')::BOOLEAN, (v_prefs->>'volleyball_granularity') IS DISTINCT FROM 'none');
                v_volley_points := COALESCE((v_prefs->>'volleyball_points')::BOOLEAN, (v_prefs->>'volleyball_granularity') = 'point');
                v_should_notify := (v_sets_changed AND v_volley_sets) OR (v_games_or_points_changed AND v_volley_points);
            END IF;
        ELSIF v_sport = 'football' THEN
            IF NOT COALESCE((v_prefs->>'football_enabled')::BOOLEAN, TRUE) THEN
                v_should_notify := FALSE;
            ELSE
                v_fb_goals := COALESCE((v_prefs->>'football_goals')::BOOLEAN, TRUE);
                v_fb_cards := COALESCE((v_prefs->>'football_cards')::BOOLEAN, TRUE);
                v_should_notify := (v_games_or_points_changed AND v_fb_goals) OR (v_cards_changed AND v_fb_cards);
            END IF;
        ELSIF v_sport = 'basketball' THEN
            IF NOT COALESCE((v_prefs->>'basketball_enabled')::BOOLEAN, TRUE) THEN
                v_should_notify := FALSE;
            ELSE
                v_bb_points := COALESCE((v_prefs->>'basketball_points')::BOOLEAN, TRUE);
                v_bb_quarters := COALESCE((v_prefs->>'basketball_quarters')::BOOLEAN, TRUE);
                v_should_notify := (v_games_or_points_changed AND v_bb_points) OR (v_quarter_changed AND v_bb_quarters);
            END IF;
        END IF;

        IF NOT v_should_notify THEN
            CONTINUE;
        END IF;

        IF v_is_milestone THEN
            INSERT INTO public.notifications (user_id, title, body, data, created_at)
            VALUES (r_follower.user_id, v_title, v_body, v_data, pg_catalog.now());
        ELSE
            SELECT id INTO v_existing_id
            FROM public.notifications
            WHERE user_id = r_follower.user_id
              AND ((data->>'match_id') = NEW.id::text OR (data->>'matchId') = NEW.id::text)
              AND (data->>'type') = 'score_update'
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
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
