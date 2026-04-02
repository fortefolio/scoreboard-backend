-- Refactor the scoring trigger to use the generic 'scores' column and handle incremental updates
CREATE OR REPLACE FUNCTION public.update_match_score()
RETURNS TRIGGER AS $$
DECLARE
    v_sport_type TEXT;
    v_scores JSONB;
    v_side TEXT;
    v_winner_idx INT;
    v_points_p1 INT;
    v_points_p2 INT;
BEGIN
    -- 1. Get current state
    SELECT sport_type, scores 
    INTO v_sport_type, v_scores
    FROM public.matches
    WHERE id = NEW.match_id;

    -- Initialize scores if empty
    IF v_scores = '{}'::jsonb OR v_scores IS NULL THEN
        v_scores := '{"current": {"home": 0, "away": 0}, "serving_index": 0}'::jsonb;
    END IF;

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
        v_winner_idx := CASE WHEN v_side = 'home' THEN 0 ELSE 1 END;

        CASE lower(v_sport_type)
            WHEN 'tennis' THEN
                -- Initialize tennis structure if missing
                IF NOT (v_scores ? 'tennis') OR v_scores->'tennis' IS NULL THEN
                    v_scores := jsonb_set(v_scores, '{tennis}', '{"points": [0,0], "games": [0,0], "sets": [], "current_set": 0}'::jsonb);
                END IF;

                -- Simple point increment logic for Tennis (Backend as Arbiter)
                -- points[winner_idx] += 1
                v_points_p1 := (v_scores->'tennis'->'points'->0)::INT;
                v_points_p2 := (v_scores->'tennis'->'points'->1)::INT;

                IF v_side = 'home' THEN v_points_p1 := v_points_p1 + 1; ELSE v_points_p2 := v_points_p2 + 1; END IF;

                -- Basic Game Win check (simplified: 4 points win the game)
                IF (v_points_p1 >= 4 AND v_points_p1 - v_points_p2 >= 2) OR (v_points_p2 >= 4 AND v_points_p2 - v_points_p1 >= 2) THEN
                    -- Winner gets the game
                    v_scores := jsonb_set(v_scores, '{tennis,games}', 
                        jsonb_set(v_scores->'tennis'->'games', 
                            ARRAY[v_winner_idx::TEXT], 
                            (((v_scores->'tennis'->'games'->v_winner_idx)::INT + 1)::TEXT)::jsonb
                        )
                    );
                    -- Reset points
                    v_scores := jsonb_set(v_scores, '{tennis,points}', '[0,0]'::jsonb);
                    -- Rotate Server
                    v_scores := jsonb_set(v_scores, '{serving_index}', (((1 - (v_scores->>'serving_index')::INT))::TEXT)::jsonb);
                ELSE
                    -- Just update points
                    v_scores := jsonb_set(v_scores, '{tennis,points}', jsonb_build_array(v_points_p1, v_points_p2));
                END IF;

            WHEN 'football', 'soccer', 'volleyball', 'beach_volleyball' THEN
                -- Increment home/away in current score
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    (((v_scores->'current'->>v_side)::INT + 1)::TEXT)::jsonb);

            WHEN 'basketball' THEN
                -- Increment by specific points (e.g., 2 or 3)
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    (((v_scores->'current'->>v_side)::INT + COALESCE((NEW.event_data->>'points')::INT, 1))::TEXT)::jsonb);

            ELSE
                -- Generic fallback
                v_scores := jsonb_set(v_scores, ARRAY['current', v_side], 
                    (((v_scores->'current'->>v_side)::INT + 1)::TEXT)::jsonb);
        END CASE;
    END IF;

    -- 4. Update the match
    UPDATE public.matches
    SET scores = v_scores,
        updated_at = NOW()
    WHERE id = NEW.match_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
