-- ============================================================================
-- Migration: 20260522020000_volleyball_and_beach_volleyball_mechanics.sql
-- Purpose:
--   1. Upgrade `public.calculate_volleyball_score` to support full FIVB Indoor
--      Volleyball (Best of 5 / Best of 3, 25 pts, 15 pt deciding set, court
--      switch at 8 pts in deciding set) and FIVB Beach Volleyball (Best of 3,
--      21 pts, 15 pt deciding set, court switch every 7/5 pts, technical
--      timeout at 21 total pts in regular sets), plus hard `point_cap`,
--      side-out vs break-point tracking, and per-set `rallies_history` +
--      `points_progression`.
--   2. Update `public.update_match_score` to dispatch `'volleyball'`,
--      `'beach_volleyball'`, and `'beach volleyball'` with sport_type context.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_volleyball_score(
    p_scores JSONB,
    v_side TEXT,
    v_rules JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_is_beach BOOLEAN := lower(COALESCE(v_rules->>'sport_type', '')) IN ('beach_volleyball', 'beach volleyball');
    v_max_sets INT := COALESCE(
        (v_rules->>'max_sets')::INT,
        CASE
            WHEN (v_rules->>'match_format') = 'best_of_5' THEN 5
            WHEN (v_rules->>'match_format') = 'best_of_1' THEN 1
            ELSE 3
        END
    );
    v_sets_to_win INT;
    v_sets JSONB := COALESCE(p_scores->'sets', p_scores->'set_scores', '[]'::jsonb);
    v_current_set INT := COALESCE((p_scores->>'current_set')::INT, jsonb_array_length(v_sets) + 1);
    v_is_deciding_set BOOLEAN;
    v_target_points INT;
    v_point_cap INT;
    v_p1_current INT := COALESCE((p_scores->'current'->>'home')::INT, 0);
    v_p2_current INT := COALESCE((p_scores->'current'->>'away')::INT, 0);
    v_prev_server INT := COALESCE((p_scores->>'serving_index')::INT, 0);
    v_winner_idx INT := CASE WHEN v_side = 'home' THEN 0 ELSE 1 END;
    v_is_sideout BOOLEAN;
    v_serving_idx INT;
    v_set_won BOOLEAN := FALSE;
    v_match_won BOOLEAN := FALSE;
    v_sets_p1 INT := 0;
    v_sets_p2 INT := 0;
    v_total_pts INT;
    v_change_ends BOOLEAN := FALSE;
    v_tech_timeout BOOLEAN := FALSE;
    v_current_set_rallies JSONB := COALESCE(p_scores->'volleyball'->'current_set_rallies', '[]'::jsonb);
    v_current_set_points JSONB := COALESCE(p_scores->'volleyball'->'current_set_points', '[]'::jsonb);
    v_s JSONB;
BEGIN
    -- Guard: Do not mutate completed matches
    IF COALESCE((p_scores->>'match_won')::BOOLEAN, FALSE) THEN
        RETURN p_scores;
    END IF;

    v_sets_to_win := CEIL(v_max_sets::NUMERIC / 2.0)::INT;
    v_is_deciding_set := (v_max_sets > 1 AND jsonb_array_length(v_sets) = (v_max_sets - 1));

    v_target_points := CASE
        WHEN v_is_deciding_set THEN COALESCE((v_rules->>'deciding_set_points')::INT, 15)
        ELSE COALESCE((v_rules->>'points_per_set')::INT, CASE WHEN v_is_beach THEN 21 ELSE 25 END)
    END;

    v_point_cap := CASE
        WHEN v_is_deciding_set AND (v_rules ? 'deciding_set_cap') AND v_rules->>'deciding_set_cap' IS NOT NULL
            THEN (v_rules->>'deciding_set_cap')::INT
        WHEN (v_rules ? 'point_cap') AND v_rules->>'point_cap' IS NOT NULL
            THEN (v_rules->>'point_cap')::INT
        ELSE NULL
    END;

    -- Rally Point Scoring: Winner scores 1 point and serves next
    IF v_side = 'home' THEN
        v_p1_current := v_p1_current + 1;
    ELSE
        v_p2_current := v_p2_current + 1;
    END IF;

    v_is_sideout := (v_winner_idx != v_prev_server);
    v_serving_idx := v_winner_idx;
    v_total_pts := v_p1_current + v_p2_current;

    -- Record rally and point progression
    v_current_set_points := v_current_set_points || to_jsonb(v_p1_current::TEXT || '-' || v_p2_current::TEXT);
    v_current_set_rallies := v_current_set_rallies || jsonb_build_array(
        jsonb_build_object(
            'rally_number', jsonb_array_length(v_current_set_rallies) + 1,
            'server', v_prev_server,
            'winner', v_winner_idx,
            'is_sideout', v_is_sideout,
            'is_break_point', NOT v_is_sideout,
            'score_after', jsonb_build_object('home', v_p1_current, 'away', v_p2_current)
        )
    );

    -- Check Set Win Condition (Hard Cap or Win-by-2 at Target)
    IF v_point_cap IS NOT NULL AND (v_p1_current >= v_point_cap OR v_p2_current >= v_point_cap) THEN
        v_set_won := TRUE;
    ELSIF (v_p1_current >= v_target_points OR v_p2_current >= v_target_points) AND ABS(v_p1_current - v_p2_current) >= 2 THEN
        v_set_won := TRUE;
    END IF;

    -- Check FIVB Court Switches & Technical Timeouts
    IF v_is_beach THEN
        -- Beach Volleyball: switch ends every 7 points in regular sets, every 5 points in deciding set, or at end of set
        IF v_set_won THEN
            v_change_ends := TRUE;
        ELSIF v_is_deciding_set AND v_total_pts > 0 AND (v_total_pts % 5 = 0) THEN
            v_change_ends := TRUE;
        ELSIF (NOT v_is_deciding_set) AND v_total_pts > 0 AND (v_total_pts % 7 = 0) THEN
            v_change_ends := TRUE;
        END IF;

        -- Beach Volleyball Technical Timeout: in regular sets when total points = 21
        IF (NOT v_is_deciding_set) AND (NOT v_set_won) AND v_total_pts = 21 THEN
            v_tech_timeout := TRUE;
        END IF;
    ELSE
        -- Indoor Volleyball: switch ends at end of set, or in deciding set when leading team first reaches 8
        IF v_set_won THEN
            v_change_ends := TRUE;
        ELSIF v_is_deciding_set
              AND GREATEST(v_p1_current, v_p2_current) = 8
              AND LEAST(v_p1_current, v_p2_current) < 8
              AND ((v_side = 'home' AND v_p1_current = 8) OR (v_side = 'away' AND v_p2_current = 8)) THEN
            v_change_ends := TRUE;
        END IF;
    END IF;

    IF v_set_won THEN
        v_sets := v_sets || jsonb_build_array(
            jsonb_build_object(
                'team1', v_p1_current,
                'team2', v_p2_current,
                'home', v_p1_current,
                'away', v_p2_current,
                'rallies_history', v_current_set_rallies,
                'points_progression', v_current_set_points
            )
        );

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
            'final_sets', jsonb_build_array(v_sets_p1, v_sets_p2),
            'current_set', CASE WHEN v_match_won THEN v_current_set ELSE v_current_set + 1 END,
            'serving_index', v_serving_idx,
            'match_won', v_match_won,
            'volleyball', jsonb_build_object(
                'current_set_rallies', '[]'::jsonb,
                'current_set_points', '[]'::jsonb,
                'last_rally_sideout', v_is_sideout,
                'change_ends', v_change_ends,
                'technical_timeout', FALSE,
                'is_deciding_set', (NOT v_match_won AND v_max_sets > 1 AND jsonb_array_length(v_sets) = (v_max_sets - 1))
            )
        );
    ELSE
        FOR v_s IN SELECT * FROM jsonb_array_elements(v_sets) LOOP
            IF COALESCE((v_s->>'team1')::INT, (v_s->>'home')::INT, 0) > COALESCE((v_s->>'team2')::INT, (v_s->>'away')::INT, 0) THEN
                v_sets_p1 := v_sets_p1 + 1;
            ELSE
                v_sets_p2 := v_sets_p2 + 1;
            END IF;
        END LOOP;

        RETURN jsonb_build_object(
            'current', jsonb_build_object('home', v_p1_current, 'away', v_p2_current),
            'sets', v_sets,
            'set_scores', v_sets,
            'final_sets', jsonb_build_array(v_sets_p1, v_sets_p2),
            'current_set', v_current_set,
            'serving_index', v_serving_idx,
            'match_won', FALSE,
            'volleyball', jsonb_build_object(
                'current_set_rallies', v_current_set_rallies,
                'current_set_points', v_current_set_points,
                'last_rally_sideout', v_is_sideout,
                'change_ends', v_change_ends,
                'technical_timeout', v_tech_timeout,
                'is_deciding_set', v_is_deciding_set
            )
        );
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Update dispatcher trigger so 'volleyball', 'beach_volleyball', and 'beach volleyball' all pass sport_type into v_rules
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match RECORD;
    v_rules JSONB;
    v_scores JSONB;
    v_result JSONB;
    v_side TEXT;
    v_match_won BOOLEAN := FALSE;
    v_football JSONB;
    v_event_type TEXT;
BEGIN
    SELECT m.*, t.settings AS tournament_settings
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    v_scores := COALESCE(v_match.scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb);
    -- Merge tournament default settings, round-specific overrides, and match-specific settings
    v_rules := jsonb_build_object('sport_type', COALESCE(v_match.sport_type, 'generic'))
        || COALESCE(v_match.tournament_settings->'default', '{}'::jsonb)
        || COALESCE(v_match.tournament_settings->'overrides'->(COALESCE(v_match.round_number, 1)::text), '{}'::jsonb)
        || COALESCE(v_match.settings, '{}'::jsonb);
    v_event_type := NEW.event_data->>'type';

    -- Handle Meta-Events
    IF v_event_type = 'start_scoreboard' THEN
        IF NEW.event_data ? 'initial_server_index' THEN
            v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->'initial_server_index'));
            UPDATE public.matches SET status = 'ongoing', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        ELSE
            UPDATE public.matches SET status = 'ongoing', updated_at = NOW() WHERE id = NEW.match_id;
        END IF;
        RETURN NEW;
    END IF;

    IF v_event_type = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->'winner_index'));
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- Handle Football clock and period events
    IF v_event_type = 'clock_toggle' THEN
        v_football := COALESCE(v_scores->'football', '{"period": 1, "is_running": false, "timer_started_at": null, "elapsed_At_pause": 0}'::jsonb);
        v_football := v_football || jsonb_build_object(
            'is_running', COALESCE((NEW.event_data->>'is_running')::boolean, false),
            'timer_started_at', NEW.event_data->'timer_started_at',
            'elapsed_At_pause', COALESCE((NEW.event_data->>'elapsed_at_pause')::int, (v_football->>'elapsed_At_pause')::int, 0)
        );
        v_scores := jsonb_set(v_scores, '{football}', v_football);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    IF v_event_type = 'period_change' THEN
        v_football := COALESCE(v_scores->'football', '{"period": 1, "is_running": false, "timer_started_at": null, "elapsed_At_pause": 0}'::jsonb);
        v_football := v_football || jsonb_build_object(
            'period', COALESCE((NEW.event_data->>'new_period')::int, 1),
            'is_running', false,
            'timer_started_at', null,
            'elapsed_At_pause', COALESCE((NEW.event_data->>'elapsed_at_pause')::int, 0)
        );
        v_scores := jsonb_set(v_scores, '{football}', v_football);
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- Dispatch scoring events
    IF v_event_type IN ('point_won', 'score', 'goal', 'point_scored') THEN
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

            WHEN 'volleyball', 'beach_volleyball', 'beach volleyball' THEN
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

    IF v_match_won AND v_match.status != 'completed' THEN
        UPDATE public.matches SET status = 'completed', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
        PERFORM public.advance_tournament_match(NEW.match_id);
    ELSE
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
