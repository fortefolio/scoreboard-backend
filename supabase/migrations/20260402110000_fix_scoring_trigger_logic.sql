-- Fix the scoring trigger: Security Definer, better JSON handling, and Volleyball Set logic
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match record;
    v_tournament record;
    v_rules JSONB;
    v_scores JSONB;
    v_side TEXT;
    v_winner_idx INT;
    v_points_p1 INT;
    v_points_p2 INT;
    v_serving_idx INT;
    -- Volleyball specific
    v_target_points INT;
    v_point_cap INT;
    v_p1_current INT;
    v_p2_current INT;
    v_set_won BOOLEAN := FALSE;
BEGIN
    -- 1. Get current state and tournament rules
    SELECT m.*, t.settings as tournament_settings 
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    v_scores := v_match.scores;

    -- Initialize scores if empty or missing 'current'
    IF v_scores IS NULL OR v_scores = '{}'::jsonb THEN
        v_scores := '{"current": {"home": 0, "away": 0}, "serving_index": 0, "sets": [], "current_set": 1}'::jsonb;
    ELSIF NOT (v_scores ? 'current') THEN
        v_scores := jsonb_set(v_scores, '{current}', '{"home": 0, "away": 0}'::jsonb);
    END IF;
    
    -- Ensure sets array and current_set index exist
    IF NOT (v_scores ? 'sets') THEN v_scores := jsonb_set(v_scores, '{sets}', '[]'::jsonb); END IF;
    IF NOT (v_scores ? 'current_set') THEN v_scores := jsonb_set(v_scores, '{current_set}', '1'::jsonb); END IF;

    -- 2. Handle Meta-Events
    IF NEW.event_data->>'type' = 'start_scoreboard' THEN
        UPDATE public.matches SET status = 'ongoing' WHERE id = NEW.match_id;
    END IF;

    IF NEW.event_data->>'type' = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->>'winner_index')::jsonb);
    END IF;

    -- 3. Handle Point/Score updates
    IF NEW.event_data->>'type' IN ('point_won', 'score', 'goal', 'point_scored') THEN
        v_side := NEW.event_data->>'side'; -- 'home' or 'away'
        IF v_side IS NULL THEN RETURN NEW; END IF;
        
        v_winner_idx := CASE WHEN v_side = 'home' THEN 0 ELSE 1 END;

        CASE lower(COALESCE(v_match.sport_type, 'generic'))
            WHEN 'tennis' THEN
                -- Initialize tennis structure if missing
                IF NOT (v_scores ? 'tennis') OR v_scores->'tennis' IS NULL THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 0}'::jsonb);
                END IF;

                v_points_p1 := (v_scores->'tennis'->'points'->0)::INT;
                v_points_p2 := (v_scores->'tennis'->'points'->1)::INT;

                IF v_side = 'home' THEN v_points_p1 := v_points_p1 + 1; ELSE v_points_p2 := v_points_p2 + 1; END IF;

                IF (v_points_p1 >= 4 AND v_points_p1 - v_points_p2 >= 2) OR (v_points_p2 >= 4 AND v_points_p2 - v_points_p1 >= 2) THEN
                    v_scores := jsonb_set(v_scores, ARRAY['tennis','games', v_winner_idx::TEXT], 
                        (((v_scores->'tennis'->'games'->v_winner_idx)::INT + 1)::TEXT)::jsonb
                    );
                    v_scores := jsonb_set(v_scores, '{tennis,points}', '[0,0]'::jsonb);
                    v_serving_idx := COALESCE((v_scores->>'serving_index')::INT, 0);
                    v_scores := jsonb_set(v_scores, '{serving_index}', ((1 - v_serving_idx)::TEXT)::jsonb);
                ELSE
                    v_scores := jsonb_set(v_scores, '{tennis,points}', jsonb_build_array(v_points_p1, v_points_p2));
                END IF;

            WHEN 'volleyball', 'beach_volleyball' THEN
                -- Determine Rules
                v_rules := CASE 
                    WHEN v_match.settings IS NOT NULL AND v_match.settings <> '{}'::jsonb THEN v_match.settings
                    WHEN v_match.tournament_settings->'overrides' ? v_match.round_number::TEXT THEN v_match.tournament_settings->'overrides'->v_match.round_number::TEXT
                    ELSE v_match.tournament_settings->'default'
                END;

                v_target_points := COALESCE((v_rules->>'points_per_set')::INT, 25);
                v_point_cap := (v_rules->>'point_cap')::INT;

                -- Increment points
                v_p1_current := (v_scores->'current'->>'home')::INT;
                v_p2_current := (v_scores->'current'->>'away')::INT;

                IF v_side = 'home' THEN v_p1_current := v_p1_current + 1; ELSE v_p2_current := v_p2_current + 1; END IF;

                -- Check if set is won
                IF (v_point_cap IS NOT NULL AND (v_p1_current = v_point_cap OR v_p2_current = v_point_cap)) THEN
                    v_set_won := TRUE;
                ELSIF (v_p1_current >= v_target_points OR v_p2_current >= v_target_points) AND ABS(v_p1_current - v_p2_current) >= 2 THEN
                    v_set_won := TRUE;
                END IF;

                IF v_set_won THEN
                    -- Append to sets array
                    v_scores := jsonb_set(v_scores, '{sets}', 
                        COALESCE(v_scores->'sets', '[]'::jsonb) || jsonb_build_object('team1', v_p1_current, 'team2', v_p2_current)
                    );
                    -- Reset current score
                    v_scores := jsonb_set(v_scores, '{current}', '{"home": 0, "away": 0}'::jsonb);
                    -- Increment current_set index
                    v_scores := jsonb_set(v_scores, '{current_set}', ((COALESCE((v_scores->>'current_set')::INT, 1) + 1)::TEXT)::jsonb);
                ELSE
                    -- Just update current points
                    v_scores := jsonb_set(v_scores, ARRAY['current', v_side], (CASE WHEN v_side = 'home' THEN v_p1_current ELSE v_p2_current END::TEXT)::jsonb);
                END IF;

            WHEN 'football', 'soccer' THEN
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);

            WHEN 'basketball' THEN
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + COALESCE((NEW.event_data->>'points')::INT, 1))::TEXT)::jsonb);

            ELSE
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    -- 4. Update the match
    UPDATE public.matches
    SET scores = v_scores,
        updated_at = NOW()
    WHERE id = NEW.match_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
