-- Refactor scoring logic into modular sport-specific functions
-- This implements the Dispatcher Pattern for better maintainability and scalability.

BEGIN;

-- ==========================================
-- 1. Specialist: Tennis
-- ==========================================
CREATE OR REPLACE FUNCTION public.calculate_tennis_score(
    p_scores JSONB,
    v_winner_idx INT,
    v_rules JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_tennis JSONB;
    v_points INT[];
    v_games INT[];
    v_sets JSONB;
    v_current_set_idx INT;
    v_is_tiebreak BOOLEAN;
    v_is_match_tiebreak BOOLEAN;
    v_opp_idx INT := 1 - v_winner_idx;
    
    -- Rule flags
    v_no_ad BOOLEAN := COALESCE((v_rules->>'no_ad')::BOOLEAN, FALSE);
    v_set_type TEXT := COALESCE(v_rules->>'set_type', 'tiebreak');
    v_match_format TEXT := COALESCE(v_rules->>'match_format', 'best_of_3');
    v_use_match_tb BOOLEAN := COALESCE((v_rules->>'match_tiebreak')::BOOLEAN, FALSE);
    
    -- Logic helpers
    v_game_won BOOLEAN := FALSE;
    v_set_won BOOLEAN := FALSE;
    v_match_won BOOLEAN := FALSE;
    v_tb_points_to_win INT := 7;
    v_total_tb_points INT;
    v_total_games_in_set INT;
    v_serving_idx INT;
BEGIN
    v_tennis := p_scores->'tennis';
    v_points := ARRAY[(v_tennis->'points'->0)::INT, (v_tennis->'points'->1)::INT];
    v_games := ARRAY[(v_tennis->'games'->0)::INT, (v_tennis->'games'->1)::INT];
    v_sets := COALESCE(v_tennis->'sets', '[]'::jsonb);
    v_current_set_idx := (v_tennis->>'current_set')::INT;
    v_is_tiebreak := COALESCE((v_tennis->>'is_tiebreak')::BOOLEAN, FALSE);
    v_serving_idx := (p_scores->>'serving_index')::INT;

    -- Check if this is a Match Tiebreak
    v_is_match_tiebreak := v_use_match_tb AND (
        (v_match_format = 'best_of_3' AND v_current_set_idx = 3) OR
        (v_match_format = 'best_of_5' AND v_current_set_idx = 5)
    );

    -- A. Update Points
    v_points[v_winner_idx + 1] := v_points[v_winner_idx + 1] + 1;

    -- B. Check for Game Win
    IF v_is_tiebreak OR v_is_match_tiebreak THEN
        v_tb_points_to_win := CASE WHEN v_is_match_tiebreak THEN 10 ELSE 7 END;
        IF v_points[v_winner_idx + 1] >= v_tb_points_to_win AND (v_points[v_winner_idx + 1] - v_points[v_opp_idx + 1]) >= 2 THEN
            v_game_won := TRUE;
        END IF;
        
        -- Tiebreak Serving Rotation
        v_total_tb_points := v_points[1] + v_points[2];
        IF v_total_tb_points % 2 = 1 THEN
            v_serving_idx := 1 - v_serving_idx;
        END IF;
    ELSE
        IF v_no_ad THEN
            IF v_points[v_winner_idx + 1] >= 4 THEN v_game_won := TRUE; END IF;
        ELSE
            IF v_points[v_winner_idx + 1] >= 4 AND (v_points[v_winner_idx + 1] - v_points[v_opp_idx + 1]) >= 2 THEN
                v_game_won := TRUE;
            ELSIF v_points[v_winner_idx + 1] = 4 AND v_points[v_opp_idx + 1] = 4 THEN
                v_points[1] := 3; v_points[2] := 3;
            END IF;
        END IF;
    END IF;

    -- C. Handle Game Won
    IF v_game_won THEN
        v_games[v_winner_idx + 1] := v_games[v_winner_idx + 1] + 1;
        v_points := ARRAY[0, 0];
        v_is_tiebreak := FALSE;
        v_serving_idx := 1 - v_serving_idx;

        IF v_is_match_tiebreak THEN
            v_set_won := TRUE;
        ELSIF v_games[v_winner_idx + 1] >= 6 THEN
            IF v_games[v_winner_idx + 1] = 7 OR (v_games[v_winner_idx + 1] - v_games[v_opp_idx + 1]) >= 2 THEN
                v_set_won := TRUE;
            ELSIF v_games[v_winner_idx + 1] = 6 AND v_games[v_opp_idx + 1] = 6 AND v_set_type = 'tiebreak' THEN
                v_is_tiebreak := TRUE;
            END IF;
        END IF;
    END IF;

    -- D. Handle Set Won
    IF v_set_won THEN
        v_sets := v_sets || jsonb_build_object('home', v_games[1], 'away', v_games[2]);
        v_games := ARRAY[0, 0];
        v_current_set_idx := v_current_set_idx + 1;
        
        DECLARE
            v_sets_p1 INT := 0; v_sets_p2 INT := 0; v_s JSONB;
        BEGIN
            FOR v_s IN SELECT * FROM jsonb_array_elements(v_sets) LOOP
                IF (v_s->>'home')::INT > (v_s->>'away')::INT THEN v_sets_p1 := v_sets_p1 + 1; ELSE v_sets_p2 := v_sets_p2 + 1; END IF;
            END LOOP;
            IF (v_match_format = 'best_of_3' AND (v_sets_p1 = 2 OR v_sets_p2 = 2)) OR
               (v_match_format = 'best_of_5' AND (v_sets_p1 = 3 OR v_sets_p2 = 3)) THEN
                v_match_won := TRUE;
            END IF;
        END;
    END IF;

    -- E. Compile Result
    v_total_games_in_set := v_games[1] + v_games[2];
    RETURN jsonb_build_object(
        'current', jsonb_build_object('home', v_games[1], 'away', v_games[2]),
        'serving_index', v_serving_idx,
        'match_won', v_match_won,
        'tennis', jsonb_build_object(
            'points', v_points,
            'games', v_games,
            'sets', v_sets,
            'current_set', v_current_set_idx,
            'is_tiebreak', v_is_tiebreak,
            'server_side', CASE WHEN (v_points[1] + v_points[2]) % 2 = 0 THEN 'deuce' ELSE 'ad' END,
            'change_ends', (v_total_games_in_set % 2 = 1 OR v_set_won)
        )
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ==========================================
-- 2. Specialist: Volleyball
-- ==========================================
CREATE OR REPLACE FUNCTION public.calculate_volleyball_score(
    p_scores JSONB,
    v_side TEXT,
    v_rules JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_target_points INT := COALESCE((v_rules->>'points_per_set')::INT, 25);
    v_point_cap INT := (v_rules->>'point_cap')::INT;
    v_p1_current INT;
    v_p2_current INT;
    v_sets JSONB := COALESCE(p_scores->'sets', '[]'::jsonb);
    v_current_set INT := COALESCE((p_scores->>'current_set')::INT, 1);
    v_set_won BOOLEAN := FALSE;
BEGIN
    v_p1_current := (p_scores->'current'->>'home')::INT;
    v_p2_current := (p_scores->'current'->>'away')::INT;

    IF v_side = 'home' THEN v_p1_current := v_p1_current + 1; ELSE v_p2_current := v_p2_current + 1; END IF;

    IF (v_point_cap IS NOT NULL AND (v_p1_current = v_point_cap OR v_p2_current = v_point_cap)) THEN
        v_set_won := TRUE;
    ELSIF (v_p1_current >= v_target_points OR v_p2_current >= v_target_points) AND ABS(v_p1_current - v_p2_current) >= 2 THEN
        v_set_won := TRUE;
    END IF;

    IF v_set_won THEN
        v_sets := v_sets || jsonb_build_object('team1', v_p1_current, 'team2', v_p2_current);
        RETURN jsonb_build_object(
            'current', '{"home": 0, "away": 0}'::jsonb,
            'sets', v_sets,
            'current_set', v_current_set + 1
        );
    ELSE
        RETURN jsonb_build_object(
            'current', jsonb_build_object('home', v_p1_current, 'away', v_p2_current),
            'sets', v_sets,
            'current_set', v_current_set
        );
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ==========================================
-- 3. The Dispatcher (Main Trigger)
-- ==========================================
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match record;
    v_rules JSONB;
    v_scores JSONB;
    v_result JSONB;
    v_side TEXT;
    v_match_won BOOLEAN := FALSE;
BEGIN
    -- 1. Load context
    SELECT m.*, t.settings as tournament_settings 
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    v_scores := COALESCE(v_match.scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb);
    v_rules := COALESCE(v_match.settings, v_match.tournament_settings->'default', '{}'::jsonb);

    -- 2. Handle Meta-Events
    IF NEW.event_data->>'type' = 'start_scoreboard' THEN
        UPDATE public.matches SET status = 'ongoing' WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    IF NEW.event_data->>'type' = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->>'winner_index')::jsonb);
        UPDATE public.matches SET scores = v_scores WHERE id = NEW.match_id;
        RETURN NEW;
    END IF;

    -- 3. Dispatch to specialist based on sport
    IF NEW.event_data->>'type' IN ('point_won', 'score', 'goal', 'point_scored') THEN
        v_side := NEW.event_data->>'side';
        IF v_side IS NULL THEN RETURN NEW; END IF;

        CASE lower(COALESCE(v_match.sport_type, 'generic'))
            WHEN 'tennis' THEN
                -- Ensure tennis object initialized
                IF NOT (v_scores ? 'tennis') THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 1, "is_tiebreak": false}'::jsonb);
                END IF;
                v_result := public.calculate_tennis_score(v_scores, (CASE WHEN v_side = 'home' THEN 0 ELSE 1 END), v_rules);
                v_match_won := COALESCE((v_result->>'match_won')::BOOLEAN, FALSE);
                v_scores := v_scores || v_result;

            WHEN 'volleyball', 'beach_volleyball' THEN
                v_result := public.calculate_volleyball_score(v_scores, v_side, v_rules);
                v_scores := v_scores || v_result;

            WHEN 'basketball' THEN
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + COALESCE((NEW.event_data->>'points')::INT, 1))::TEXT)::jsonb);

            ELSE -- Football, Soccer, Generic
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    -- 4. Final Updates
    IF v_match_won THEN
        UPDATE public.matches SET status = 'completed', scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    ELSE
        UPDATE public.matches SET scores = v_scores, updated_at = NOW() WHERE id = NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

COMMIT;
