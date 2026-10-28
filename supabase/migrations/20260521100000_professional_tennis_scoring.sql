-- Migration: Professional Tennis Scoring Logic
-- Implements professional tennis rules including tie-breaks, advantage scoring, and server rotation.

CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_match record;
    v_rules JSONB;
    v_scores JSONB;
    v_tennis JSONB;
    v_side TEXT;
    v_winner_idx INT;
    v_opp_idx INT;
    
    -- Scoring state
    v_points INT[];
    v_games INT[];
    v_sets JSONB;
    v_current_set_idx INT;
    v_is_tiebreak BOOLEAN;
    v_is_match_tiebreak BOOLEAN;
    
    -- Rule flags
    v_no_ad BOOLEAN;
    v_set_type TEXT; -- 'tiebreak' or 'advantage'
    v_match_format TEXT; -- 'best_of_3' or 'best_of_5'
    v_use_match_tb BOOLEAN; -- Use 10pt tiebreak instead of final set
    
    -- Logic helpers
    v_game_won BOOLEAN := FALSE;
    v_set_won BOOLEAN := FALSE;
    v_match_won BOOLEAN := FALSE;
    v_tb_points_to_win INT := 7;
    v_total_tb_points INT;
    v_total_games_in_set INT;
BEGIN
    -- 1. Get current state and configuration
    SELECT m.*, t.settings as tournament_settings 
    INTO v_match
    FROM public.matches m
    LEFT JOIN public.tournaments t ON m.tournament_id = t.id
    WHERE m.id = NEW.match_id;

    v_scores := COALESCE(v_match.scores, '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb);
    
    -- Initialize Tennis object if missing
    IF NOT (v_scores ? 'tennis') THEN
        v_scores := jsonb_set(v_scores, '{tennis}', '{
            "points": [0, 0],
            "games": [0, 0],
            "sets": [],
            "current_set": 1,
            "is_tiebreak": false,
            "server_side": "deuce",
            "change_ends": false
        }'::jsonb);
    END IF;

    v_tennis := v_scores->'tennis';
    
    -- Load Config (Match Settings override Tournament Defaults)
    v_rules := COALESCE(v_match.settings, v_match.tournament_settings->'default', '{}'::jsonb);
    v_no_ad := COALESCE((v_rules->>'no_ad')::BOOLEAN, FALSE);
    v_set_type := COALESCE(v_rules->>'set_type', 'tiebreak');
    v_match_format := COALESCE(v_rules->>'match_format', 'best_of_3');
    v_use_match_tb := COALESCE((v_rules->>'match_tiebreak')::BOOLEAN, FALSE);

    -- 2. Handle Meta-Events
    IF NEW.event_data->>'type' = 'start_scoreboard' THEN
        UPDATE public.matches SET status = 'ongoing' WHERE id = NEW.match_id;
    END IF;

    IF NEW.event_data->>'type' = 'toss_coin' THEN
        v_scores := jsonb_set(v_scores, '{serving_index}', (NEW.event_data->>'winner_index')::jsonb);
    END IF;

    -- 3. Handle Scoring Logic
    IF NEW.event_data->>'type' IN ('point_won', 'point_scored') THEN
        v_side := NEW.event_data->>'side';
        IF v_side IS NULL THEN RETURN NEW; END IF;
        
        v_winner_idx := CASE WHEN v_side = 'home' THEN 0 ELSE 1 END;
        v_opp_idx := 1 - v_winner_idx;

        CASE lower(COALESCE(v_match.sport_type, 'generic'))
            WHEN 'tennis' THEN
                v_points := ARRAY[(v_tennis->'points'->0)::INT, (v_tennis->'points'->1)::INT];
                v_games := ARRAY[(v_tennis->'games'->0)::INT, (v_tennis->'games'->1)::INT];
                v_sets := COALESCE(v_tennis->'sets', '[]'::jsonb);
                v_current_set_idx := (v_tennis->>'current_set')::INT;
                v_is_tiebreak := COALESCE((v_tennis->>'is_tiebreak')::BOOLEAN, FALSE);

                -- Check if this is a Match Tiebreak (Super TB)
                -- Usually replaces the 3rd set (in best of 3) or 5th set (in best of 5)
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
                    
                    -- Tiebreak Serving Rotation: Point 1 (A), 2-3 (B), 4-5 (A), 6-7 (B)...
                    v_total_tb_points := v_points[1] + v_points[2];
                    IF v_total_tb_points % 2 = 1 THEN
                        v_scores := jsonb_set(v_scores, '{serving_index}', ((1 - (v_scores->>'serving_index')::INT)::TEXT)::jsonb);
                    END IF;
                ELSE
                    -- Standard Game Logic (0, 15, 30, 40)
                    -- Internal: 0=0, 1=15, 2=30, 3=40, 4=Advantage, 5=Win
                    IF v_no_ad THEN
                        IF v_points[v_winner_idx + 1] >= 4 THEN v_game_won := TRUE; END IF;
                    ELSE
                        IF v_points[v_winner_idx + 1] >= 4 AND (v_points[v_winner_idx + 1] - v_points[v_opp_idx + 1]) >= 2 THEN
                            v_game_won := TRUE;
                        ELSIF v_points[v_winner_idx + 1] = 4 AND v_points[v_opp_idx + 1] = 4 THEN
                            -- Back to Deuce (3-3)
                            v_points[1] := 3; v_points[2] := 3;
                        END IF;
                    END IF;
                END IF;

                -- C. Handle Game Won
                IF v_game_won THEN
                    v_games[v_winner_idx + 1] := v_games[v_winner_idx + 1] + 1;
                    v_points := ARRAY[0, 0];
                    v_is_tiebreak := FALSE;
                    
                    -- Rotate Server for next game (unless it's the end of a TB which handles it differently)
                    v_scores := jsonb_set(v_scores, '{serving_index}', ((1 - (v_scores->>'serving_index')::INT)::TEXT)::jsonb);

                    -- Check for Set Win
                    IF v_is_match_tiebreak THEN
                        v_set_won := TRUE; -- Match tiebreak wins the set (and match)
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
                    -- Record Set Result
                    v_sets := v_sets || jsonb_build_object('home', v_games[1], 'away', v_games[2]);
                    
                    -- Reset for next set
                    v_games := ARRAY[0, 0];
                    v_current_set_idx := v_current_set_idx + 1;
                    
                    -- Check for Match Win
                    DECLARE
                        v_sets_p1 INT := 0;
                        v_sets_p2 INT := 0;
                        v_s JSONB;
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

                -- E. Track Sides & End Changes
                -- Court side alternates every point in standard game
                -- Deuce side on even point totals, Ad side on odd.
                v_tennis := v_tennis || jsonb_build_object(
                    'points', v_points,
                    'games', v_games,
                    'sets', v_sets,
                    'current_set', v_current_set_idx,
                    'is_tiebreak', v_is_tiebreak,
                    'server_side', CASE WHEN (v_points[1] + v_points[2]) % 2 = 0 THEN 'deuce' ELSE 'ad' END
                );

                -- Change Ends if total games in set is odd
                v_total_games_in_set := v_games[1] + v_games[2];
                v_tennis := jsonb_set(v_tennis, '{change_ends}', (v_total_games_in_set % 2 = 1 OR v_set_won)::TEXT::jsonb);

                v_scores := jsonb_set(v_scores, '{tennis}', v_tennis);
                
                -- Sync high-level current score
                v_scores := jsonb_set(v_scores, '{current}', jsonb_build_object('home', v_games[1], 'away', v_games[2]));

            ELSE
                -- Non-Tennis logic (unchanged)
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    ((COALESCE((v_scores->'current'->>v_side)::INT, 0) + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    -- 4. Final Updates
    IF v_match_won THEN
        UPDATE public.matches SET status = 'completed' WHERE id = NEW.match_id;
    END IF;

    UPDATE public.matches
    SET scores = v_scores,
        updated_at = NOW()
    WHERE id = NEW.match_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
