-- Support Padel in Scoring Dispatcher Trigger
-- Padel uses the same game/set structure as tennis, with Ponto de Ouro (Golden Point / no_ad: true) by default.

BEGIN;

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
            UPDATE public.matches SET status = 'ongoing', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
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
            WHEN 'tennis', 'padel' THEN
                IF NOT (v_scores ? 'tennis') THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 1, "is_tiebreak": false}'::jsonb);
                END IF;
                -- Default no_ad (Ponto de Ouro / Golden Point) to TRUE for Padel unless explicitly configured
                IF lower(COALESCE(v_match.sport_type, '')) = 'padel' AND NOT (v_rules ? 'no_ad') THEN
                    v_rules := jsonb_set(v_rules, '{no_ad}', 'true'::jsonb);
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

COMMIT;
